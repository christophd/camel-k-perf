package client

import (
	"os"
	"path/filepath"

	"github.com/mitchellh/go-homedir"
	"github.com/nicolaferraro/camel-k-perf/pkg/apis"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

func NewClient() (client.Client, error) {
	kubeconfig, err := kubeconfig()
	if err != nil {
		return nil, err
	}
	config, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(&clientcmd.ClientConfigLoadingRules{ExplicitPath: kubeconfig}, &clientcmd.ConfigOverrides{}).ClientConfig()
	if err != nil {
		return nil, err
	}

	customScheme := scheme.Scheme
	if err := apis.AddToScheme(customScheme); err != nil {
		return nil, err
	}
	clientOptions := client.Options{
		Scheme: customScheme,
	}
	return client.New(config, clientOptions)
}

func kubeconfig() (string, error) {
	kubeconfig := os.Getenv("KUBECONFIG")
	if kubeconfig != "" {
		return kubeconfig, nil
	}

	dir, err := homedir.Dir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, ".kube", "config"), nil
}
