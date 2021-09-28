package cli

import (
	"errors"
	"fmt"
	"regexp"
	"strconv"

	project "github.com/openshift/api/project/v1"
	"github.com/spf13/cobra"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ctrl "sigs.k8s.io/controller-runtime/pkg/client"
)

func newCmdGenerate(rootCmdOptions *RootCmdOptions) *cobra.Command {
	options := GenerateCmdOptions{
		RootCmdOptions: rootCmdOptions,
	}
	cmd := cobra.Command{
		Use:   "generate [template file]",
		Short: "Generate users from a template.",

		PreRunE: options.preRun,
		RunE:    options.run,
	}

	cmd.Flags().IntVar(&options.Number, "number", 1, "The number of users to simulate")

	return &cmd
}

type GenerateCmdOptions struct {
	*RootCmdOptions
	Number int
}

func (o *GenerateCmdOptions) preRun(cmd *cobra.Command, _ []string) error {
	if o.Number <= 0 {
		return errors.New(`Flag "number" must be positive`)
	}
	return nil
}

func (o *GenerateCmdOptions) run(cmd *cobra.Command, _ []string) error {
	last, err := o.getLastProject()
	if err != nil {
		return err
	}
	for i := last + 1; i < last+1+o.Number; i++ {
		name := fmt.Sprintf("perf-%05d", i)
		p := project.Project{
			ObjectMeta: metav1.ObjectMeta{
				Name: name,
				Labels: map[string]string{
					"perf.generated": "true",
				},
			},
		}
		if err := o.Client.Create(o.Ctx, &p); err != nil {
			return err
		}
		fmt.Printf("Project %s created\n", name)
	}

	return nil
}

func (o *GenerateCmdOptions) getLastProject() (int, error) {
	projects := project.ProjectList{}
	if err := o.Client.List(o.Ctx, &projects, ctrl.MatchingLabels{"perf.generated": "true"}); err != nil {
		return 0, err
	}
	reg := regexp.MustCompile("^[^-]*-([0-9]+)$")
	last := 0
	for _, p := range projects.Items {
		if reg.MatchString(p.Name) {
			matches := reg.FindStringSubmatch(p.Name)
			if len(matches) > 1 {
				num, err := strconv.Atoi(matches[1])
				if err != nil {
					return 0, err
				}
				if num > last {
					last = num
				}
			}
		}
	}
	return last, nil
}
