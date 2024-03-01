defmodule RESTez.Schema do

  @moduledoc false

  require IEx

  @attributes_key :__attributes__
  def attributes_key, do: @attributes_key

  def map_schema({root, schema}) do
    map_schema(schema, root, [], [])
  end

  defp map_schema({k, %{id: _id} = v}, path, attributes, acc) do
    final_path = Path.join(path, k)
    {curr_attrs, rest} = pop_attributes(v)
    final_attrs = merge_attributes(curr_attrs, attributes) |> Map.new
    def = Map.merge(final_attrs, rest) |> Map.put(:path_template, {final_path, escape(__ENV__)})
    [def | acc]
  end

  defp map_schema({k, v}, path, attributes, acc) when is_map(v) do
    new_path = Path.join(path, k)
    {current_attrs, rest} = pop_attributes(v)
    new_attrs = merge_attributes(current_attrs, attributes)

    Enum.reduce(rest, acc, fn kv, curr_acc ->
      map_schema(kv, new_path, new_attrs, curr_acc)
    end)
  end

  defp map_schema(map, path, attributes, acc) when is_map(map) do
    {current_attrs, rest} = pop_attributes(map)
    new_attrs = merge_attributes(current_attrs, attributes)
    Enum.reduce(rest, acc, fn kv, curr_acc ->
      map_schema(kv, path, new_attrs, curr_acc)
    end)
  end

  def get_required_params(url, parameter_regex, inner_regex) do
    captures = List.flatten(Regex.scan(parameter_regex, url, capture: :all_but_first))
    Enum.map(captures, fn c -> String.to_atom(hd(hd(Regex.scan(inner_regex, c, capture: :all_but_first)))) end)
  end

  def interpolate_url(url, params, parameter_regex, inner_regex) do
    captures = List.flatten(Regex.scan(parameter_regex, url, capture: :all_but_first))
    Enum.reduce(captures, url, fn c, acc ->
      key = String.to_atom(hd(hd(Regex.scan(inner_regex, c, capture: :all_but_first))))
      String.replace(acc, c, params[key] |> to_string())
    end)
  end

  def resolve_attributes(def) do
    resolved = Enum.map(def, &resolve_attribute/1) |> Map.new()
    Map.merge(def, resolved)
  end

  defp resolve_attribute({k, {ast, context}}) do
    {context, _} = Code.eval_quoted(context)
    {value, _} = Code.eval_quoted(ast, [], context)
    {k, value}
  end
  defp resolve_attribute({k, v}), do: {k, v}

  def pop_attributes(scope), do: Map.pop(scope, @attributes_key, [])
  def merge_attributes(new, existing), do: Keyword.merge(existing, new)

  defp escape(value, opts \\ []), do: Macro.escape(value, opts)
end
