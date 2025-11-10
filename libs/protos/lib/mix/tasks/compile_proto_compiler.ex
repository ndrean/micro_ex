defmodule Mix.Tasks.Compile.ProtoCompiler do
  use Mix.Task

  @moduledoc """
  A Mix task to compile protobuf definitions using protoc.

  This compiler only runs when the :proto_compiler config is present.
  When used as a dependency in other apps, it skips compilation.
  """

  @impl Mix.Task
  def run(_) do
    config = Mix.Project.config()

    # Only run the compiler if we're in the protos project itself
    # When client_svc depends on protos, this compiler runs twice:
    # 1. In protos (compiles .proto files)
    # 2. In client_svc (should skip - no proto_compiler config)
    case Keyword.get(config, :proto_compiler) do
      nil ->
        # Skip compilation - we're in a consuming app (e.g., client_svc)
        # The compiled .pb.ex files are already in protos/lib/protos/
        :noop

      proto_config ->
        # We're in the protos lib itself - compile the .proto files
        check_protoc_path()

        cwd = File.cwd!()
        source_dir = Path.join(cwd, Keyword.fetch!(proto_config, :source_dir))
        output_dir = Path.join(cwd, Keyword.fetch!(proto_config, :output_dir))

        File.mkdir_p!(output_dir)

        File.ls!(source_dir)
        |> Enum.filter(&String.ends_with?(&1, ".proto"))
        |> Enum.map(&Path.join(source_dir, &1))
        |> compile_proto_files(source_dir, output_dir)
    end
  end

  defp check_protoc_path do
    System.find_executable("protoc") ||
      Mix.raise("protoc executable not found in PATH. Please install Protocol Buffers compiler.")
  end

  defp compile_proto_files(files, source_dir, output_dir) do
    Mix.shell().info("Compiling #{length(files)} protobuf files")

    case System.cmd("protoc", protoc_args(source_dir, output_dir, files)) do
      {_, 0} ->
        :ok

      {error_message, exit_code} ->
        Mix.raise("protoc failed with exit code #{exit_code}: #{error_message}")
    end
  end

  defp protoc_args(source_dir, output_dir, files) do
    [
      "--elixir_out=#{output_dir}",
      "--proto_path=#{source_dir}",
      files
    ]
    |> List.flatten()
  end
end
