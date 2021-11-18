package cli

import (
	"context"

	"github.com/nicolaferraro/camel-k-perf/pkg/client"
	"github.com/spf13/cobra"
	runtime "sigs.k8s.io/controller-runtime/pkg/client"
)

func NewPerfCommand(ctx context.Context) (*cobra.Command, error) {
	c, err := client.NewClient()
	if err != nil {
		return nil, err
	}
	options := RootCmdOptions{
		Ctx:    ctx,
		Client: c,
	}
	cmd := cobra.Command{
		Use:   "perf",
		Short: "Perf is a performance test utility",
	}

	cmd.AddCommand(newCmdGenerate(&options))

	return &cmd, nil
}

type RootCmdOptions struct {
	Ctx    context.Context
	Client runtime.Client
}
