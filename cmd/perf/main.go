package main

import (
	"context"
	"os"

	"github.com/nicolaferraro/camel-k-perf/pkg/cli"
)

func main() {
	if err := run(); err != nil {
		os.Exit(1)
	}
}

func run() error {
	ctx := context.Background()
	cmd, err := cli.NewPerfCommand(ctx)
	if err != nil {
		return err
	}
	return cmd.Execute()
}
