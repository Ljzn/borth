defmodule Borth.Compiler do
  @moduledoc """
  C stands for compiler.
  """
  alias Borth.Parser, as: P

  @ignore_ops ~w(
    cr
    .
  )a

  @doc """
  Parse the string code into a map of definations.

  ## Examples

      iex> code = ": add1 1 add ; : add2 add1 add1 ;"
      ...> C.parse(code)
      %{add1: [1, :add], add2: [:add1, :add1]}

  """
  def parse(str) do
    # delete \ comments
    str = delete_slash_comments(str)

    {:ok, result, _, _, _, _} = P.simple_forth(str)
    # |> U.debug(lable: "after parse")

    for {k, v} <- result, into: %{} do
      {k, v}
    end
    # |> U.debug(label: "parsed", limit: :infinity)
    |> inject_imports()
  end

  defp delete_slash_comments(str) do
    str
    |> String.split("\n")
    |> Enum.reject(fn x ->
      x = String.trim_leading(x)
      String.starts_with?(x, "\\")
    end)
    |> Enum.join("\n")
  end

  def inject_imports(dict) do
    case dict[:import] do
      nil ->
        dict

      imports when is_list(imports) ->
        Enum.reduce(imports, dict, fn path, acc ->
          path = extension(path)

          read_imports_code(path)
          |> parse()
          |> replace()
          |> add_module_prefix(path)
          |> Map.merge(acc)
        end)
    end
  end

  defp extension(path) do
    if String.ends_with?(path, ".fth") do
      path
    else
      path <> ".fth"
    end
  end

  defp read_imports_code(path) do
    File.read!(path)
  end

  defp add_module_prefix(dict, path) do
    module_name = Path.basename(path, ".fth")

    for {k, v} <- dict, into: %{} do
      {String.to_atom(module_name <> ":" <> Atom.to_string(k)), v}
    end
  end

  @doc """
  Replace the user defined keywrod.
  The max round is 1000.

  ## Examples

      iex> C.replace(%{add1: [1, :add], add2: [:add1, :add1]})
      %{add1: [1, :add], add2: [1, :add, 1, :add]}

  """
  def replace(map) do
    do_replace(map, 0)
  end

  defp do_replace(_map, 1000), do: raise("reach max replace limit")

  defp do_replace(map, t) do
    map1 =
      Enum.reduce(map, map, fn {k, v}, acc ->
        Enum.reduce(acc, %{}, fn {k0, v0}, acc1 ->
          Map.put(acc1, k0, update_sentance(v0, k, v))
        end)
      end)

    if map1 == map do
      map1
    else
      do_replace(map1, t + 1)
    end
  end

  defp update_sentance(s, k, v) do
    for w <- s do
      if w == k do
        v
      else
        w
      end
    end
    |> List.flatten()
  end

  def to_asm_string(list) do
    list
    |> Enum.reject(fn x -> x in @ignore_ops end)
    |> Enum.map(&do_to_asm_string/1)
    |> Enum.join(" ")
  end

  defp do_to_asm_string(""), do: "OP_0"
  defp do_to_asm_string(:+), do: "OP_ADD"
  defp do_to_asm_string(:-), do: "OP_SUB"
  defp do_to_asm_string(:*), do: "OP_MUL"
  defp do_to_asm_string(:/), do: "OP_DIV"
  defp do_to_asm_string(:%), do: "OP_MOD"
  defp do_to_asm_string(:=), do: "OP_EQUAL"
  defp do_to_asm_string(:<), do: "OP_LESSTHAN"
  defp do_to_asm_string(:>), do: "OP_GREATERTHAN"
  defp do_to_asm_string(:>=), do: "OP_GREATERTHANOREQUAL"
  defp do_to_asm_string(:<=), do: "OP_LESSTHANOREQUAL"
  defp do_to_asm_string(:"1-"), do: "OP_1SUB"
  defp do_to_asm_string(:"1+"), do: "OP_1DD"
  defp do_to_asm_string(:fas), do: "OP_FROMALTSTACK"
  defp do_to_asm_string(:tas), do: "OP_TOALTSTACK"
  defp do_to_asm_string(:and), do: "OP_BOOLAND"
  defp do_to_asm_string(:or), do: "OP_BOOLOR"
  defp do_to_asm_string(:&), do: "OP_AND"
  defp do_to_asm_string(:|), do: "OP_OR"
  defp do_to_asm_string(:^), do: "OP_XOR"
  defp do_to_asm_string(:"~"), do: "OP_INVERT"
  defp do_to_asm_string(:"=verify"), do: "OP_EQUALVERIFY"
  defp do_to_asm_string(:"num="), do: "OP_NUMEQUAL"
  defp do_to_asm_string(:"num=verify"), do: "OP_NUMEQUALVERIFY"
  defp do_to_asm_string(:not0), do: "OP_0NOTEQUAL"

  defp do_to_asm_string(atom) when is_atom(atom),
    do: "OP_" <> (to_string(atom) |> String.upcase())

  defp do_to_asm_string(-1), do: "OP_1NEGATE"
  defp do_to_asm_string(x) when x in 0..16, do: "OP_#{x}"

  defp do_to_asm_string(x) when is_integer(x),
    do: x |> :interpreter.num2bin() |> Base.encode16(case: :lower)

  defp do_to_asm_string(x) when is_binary(x), do: Base.encode16(x, case: :lower)

  def compile(map) do
    for {k, v} <- map, into: %{} do
      {
        k,
        v
        |> :borth_compiler.compile_literal()
        |> :borth_compiler.unroll()
      }
    end
  end

  @core_string File.read!("core/core.fth")

  def interpret_core_word(op) do
    @core_string |> parse() |> replace() |> Map.get(op) || [op]
  end
end
