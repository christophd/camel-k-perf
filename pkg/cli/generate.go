package cli

import (
	"fmt"
	"io/ioutil"
	"math/rand"
	"os"
	"strings"
	"sync"
	"time"

	project "github.com/openshift/api/project/v1"
	openshiftv1 "github.com/openshift/api/template/v1"
	"github.com/spf13/cobra"
	k8serrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/apimachinery/pkg/util/yaml"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

func newCmdGenerate(rootCmdOptions *RootCmdOptions) *cobra.Command {
	options := GenerateCmdOptions{
		RootCmdOptions: rootCmdOptions,
	}
	cmd := cobra.Command{
		Use:   "generate [template file]",
		Short: "Generate resources from a template file in parallel.",

		PreRunE: options.preRun,
		RunE:    options.run,
	}

	cmd.Flags().StringVar(&options.NamespacePrefix, "namespace-prefix", "", "The prefix of the namespaces used to inject data (need to be pre-existing)")
	cmd.Flags().StringVar(&options.NamespaceSuffix, "namespace-suffix", "", "The suffix of the namespaces used to inject data (need to be pre-existing)")
	cmd.Flags().IntVar(&options.Parallelism, "parallelism", -1, "The maximum number of user load to create in parallel (infinite if less than or equal to 0)")
	cmd.Flags().IntVar(&options.Number, "number", 1, "The number of users to simulate")
	cmd.Flags().IntVar(&options.Attempts, "attempts", 5, "The number of times the creation of a resource should be attempted before giving up")

	return &cmd
}

type GenerateCmdOptions struct {
	*RootCmdOptions
	NamespacePrefix string
	NamespaceSuffix string
	Template        string
	Number          int
	Attempts        int
	Parallelism     int
}

func (o *GenerateCmdOptions) preRun(cmd *cobra.Command, args []string) error {
	if o.Number <= 0 {
		return fmt.Errorf(`flag "number" must be greater than 0: %d`, o.Number)
	}

	if len(args) < 1 {
		return fmt.Errorf("you must provide a template file")
	}
	o.Template = args[0]

	if nfo, err := os.Stat(o.Template); err != nil {
		return fmt.Errorf("error while opening file %q: %w", o.Template, err)
	} else {
		if nfo.IsDir() {
			return fmt.Errorf("file %q is a directory", o.Template)
		}
	}

	return nil
}

func (o *GenerateCmdOptions) run(cmd *cobra.Command, _ []string) error {
	projects, err := o.getProjectNames()
	if err != nil {
		return err
	}
	if len(projects) < o.Number {
		return fmt.Errorf("Not enough projects to create load into: found %d, required %d", len(projects), o.Number)
	}

	resources, err := o.loadResources()
	if err != nil {
		return err
	} else if len(resources) == 0 {
		return fmt.Errorf("no resources found in the provided file")
	}

	wg := sync.WaitGroup{}
	wg.Add(o.Number)

	parallelism := o.Parallelism
	if parallelism <= 0 {
		parallelism = o.Number
	}
	sig := make(chan bool, parallelism)
	for i := 0; i < parallelism; i++ {
		sig <- true
	}

	errors := make(chan error, o.Number)

	for i := 0; i < o.Number; i++ {
		go o.generateWithGuard(&wg, sig, errors, resources, projects[i])
	}
	wg.Wait()
	close(errors)
	var lastError error
	for err, ok := <-errors; ok; err, ok = <-errors {
		lastError = err
		fmt.Fprintf(os.Stderr, "An error occurred during generation: %v\n", err)
	}
	return lastError
}

func (o *GenerateCmdOptions) generateWithGuard(wg *sync.WaitGroup, sig chan bool, errors chan error, resources []client.Object, namespace string) {
	defer func() {
		sig <- true
		wg.Done()
	}()
	<-sig
	if err := o.generate(resources, namespace); err != nil {
		errors <- err
	}
}

func (o *GenerateCmdOptions) generate(resources []client.Object, namespace string) error {
	for _, res := range resources {
		copy := res.DeepCopyObject()
		if obj, ok := copy.(client.Object); ok {
			obj.SetNamespace(namespace)
			if err := o.ensureCreatedGuard(obj); err != nil {
				return err
			}
		} else {
			return fmt.Errorf("invalid object")
		}
	}
	return nil
}

func (o *GenerateCmdOptions) ensureCreatedGuard(obj client.Object) error {
	var lastError error
	for i := 0; i < o.Attempts; i++ {
		if err := o.ensureCreated(obj); err == nil {
			return nil
		} else {
			lastError = err
		}
		if i < o.Attempts-1 {
			backoff := rand.Int63n(10)
			if backoff < 1 {
				backoff = 1
			}
			fmt.Printf("Error while creating the %q resource in namespace %q, waiting %d seconds...\n", obj.GetName(), obj.GetNamespace(), backoff)
			time.Sleep(time.Duration(backoff) * time.Second)
		}
	}
	fmt.Printf("Unable to create resource %q in namespace %q\n", obj.GetName(), obj.GetNamespace())
	return lastError
}

func (o *GenerateCmdOptions) ensureCreated(obj client.Object) error {
	if err := o.Client.Create(o.Ctx, obj); err == nil {
		fmt.Printf("Resource %q in namespace %q created\n", obj.GetName(), obj.GetNamespace())
		return nil
	} else if k8serrors.IsAlreadyExists(err) {
		fmt.Printf("Resource %q in namespace %q already existing (skipping)\n", obj.GetName(), obj.GetNamespace())
		return nil
	} else {
		return err
	}
}

func (o *GenerateCmdOptions) loadResources() ([]client.Object, error) {
	data, err := ioutil.ReadFile(o.Template)
	if err != nil {
		return nil, err
	}
	template := openshiftv1.Template{}
	if err := yaml.Unmarshal(data, &template); err != nil {
		return nil, err
	}
	var res = make([]client.Object, 0, len(template.Objects))
	for _, obj := range template.Objects {
		o, err := o.unmarshal(obj.Raw)
		if err != nil {
			return nil, err
		}
		res = append(res, o)
	}
	return res, nil
}

func (o *GenerateCmdOptions) unmarshal(raw []byte) (client.Object, error) {
	codecs := serializer.NewCodecFactory(o.Client.Scheme())
	deserializer := codecs.UniversalDeserializer()
	obj, _, err := deserializer.Decode(raw, nil, nil)
	if err != nil {
		return nil, err
	}
	if co, ok := obj.(client.Object); ok {
		return co, nil
	}
	return nil, fmt.Errorf("cannot convert the resource to client object")
}

func (o *GenerateCmdOptions) toRuntimeObject(u *unstructured.Unstructured) (client.Object, error) {
	gvk := u.GroupVersionKind()
	codecs := serializer.NewCodecFactory(o.Client.Scheme())
	decoder := codecs.UniversalDecoder(gvk.GroupVersion())

	b, err := u.MarshalJSON()
	if err != nil {
		return nil, fmt.Errorf("error running MarshalJSON on unstructured object: %w", err)
	}
	ro, _, err := decoder.Decode(b, &gvk, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to decode json data with gvk(%v): %w", gvk.String(), err)
	}
	if o, ok := ro.(client.Object); ok {
		return o, nil
	}
	return nil, fmt.Errorf("cannot cast resource to client object")
}

func (o *GenerateCmdOptions) getProjectNames() ([]string, error) {
	projects := project.ProjectList{}
	if err := o.Client.List(o.Ctx, &projects); err != nil {
		return nil, err
	}
	var res []string
	for _, p := range projects.Items {
		if strings.HasPrefix(p.Name, o.NamespacePrefix) && strings.HasSuffix(p.Name, o.NamespaceSuffix) {
			res = append(res, p.Name)
		}
	}
	return res, nil
}
