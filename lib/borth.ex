defmodule Borth do
  @moduledoc """
  """
  alias Borth.Compiler, as: C

  defp concat(x, y), do: x <> "\n" <> y

  defp prelude() do
    File.read!("core/core.fth")
  end

  defmacro sigil_B({_, _, [str]}, _modifiers) do
    run_code(str)
  end

  def run_code(code) do
    core = prelude()

    code
    |> concat(core)
    |> full_compile()
    |> Map.get(:main)
    |> :borth_rt.eval()
  end

  defp full_compile(code) do
    code
    |> C.parse()
    |> C.replace()
    |> C.compile()
  end

  def to_asm(code) do
    {_, core_ext} = prelude()

    concat(core_ext, code)
    |> full_compile()
    |> Map.get(:main)
    |> C.to_asm_string()
  end
end
