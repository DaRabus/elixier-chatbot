defmodule Chatbot.Shell do
  @moduledoc """
  Runs an executable with an argument list (never through a shell, so no injection via args)
  with a timeout. Tools that touch the outside world should use this.
  """

  @spec run(String.t(), [String.t()], timeout()) :: {:ok, String.t()} | {:error, String.t()}
  def run(cmd, args, timeout \\ 60_000) do
    if System.find_executable(cmd) do
      task = Task.async(fn -> System.cmd(cmd, args, stderr_to_stdout: true) end)

      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, {out, 0}} -> {:ok, out}
        {:ok, {out, code}} -> {:error, "exit #{code}: #{out}"}
        _ -> {:error, "timed out after #{timeout}ms"}
      end
    else
      {:error, "executable not found: #{cmd}"}
    end
  end
end
