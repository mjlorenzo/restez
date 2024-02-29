defmodule RESTez.Schema.Notation do

  require IEx

  @base_module RESTez.Schema
  import RESTez.Schema
  Code.ensure_compiled!(@base_module)

  @scope_stack_key :scope_stack
  @attributes_key @base_module.attributes_key

  defmacro schema(schema_def) do
    quote bind_quoted: [schema_def: schema_def] do
      def __schema__, do: unquote(Macro.escape(schema_def))
    end
  end

  defmacro schema(root, attrs) do
    caller = __CALLER__
    {do_block, rest} = pop_do_block!(caller, attrs)
    scope = new_scope(caller, rest)
    push_scope(caller, scope)
    [
      do_block,
      quote(do: unquote(__MODULE__).finalize_schema(unquote(root))),
    ]
  end

  defmacro route(path, attrs) do
    caller = __CALLER__
    {do_block, rest} = pop_do_block!(caller, attrs)

    new_scope = new_scope(caller, rest)
    push_scope(caller, new_scope)
    [
      do_block,
      quote do: unquote(__MODULE__).close_route(unquote(path))
    ]
  end

  defmacro endpoint(path, name, description \\ []) do
    caller = __CALLER__
    current_scope = pop_scope(caller)
    endpoint_scope = new_scope(caller, description) |> Map.put(:id, {name, escape(caller)})
    new_scope = Map.put(current_scope, path, endpoint_scope)
    push_scope(caller, new_scope)
  end

  defp escape(value, opts \\ []), do: Macro.escape(value, opts)

  defmacro attribute(key, value_or_do) do
    caller = __CALLER__
    escaped = escape(caller)
    context = if Macro.quoted_literal?(value_or_do) do
      {value_or_do, escaped}
    else
      {do_block, _} = pop_do_block!(caller, value_or_do)
      {do_block, escaped}
    end
    _attr(__CALLER__, key, context)
  end

  defmacro runtime_attr(key, keywords) do
    caller = __CALLER__
    {do_block, _} = pop_do_block!(caller, keywords)
    context = {do_block, escape(caller)}
    _attr(caller, key, context)
  end

  defp _attrs(caller, values), do: Enum.map(values, fn {k, v} -> {k, {v, escape(caller)}} end)

  defp _attr(caller, key, value) do
    current_scope = pop_scope(caller)
    new_scope = put_attribute(current_scope, key, value)
    push_scope(caller, new_scope)
  end

  defmacro close_route(path) do
    caller = __CALLER__
    current = pop_scope(caller)
    parent = pop_scope(caller)
    final = Map.put(parent, path, current)
    push_scope(caller, final)
  end

  defmacro finalize_schema(base_url) do
    caller = __CALLER__
    sub_schema = pop_scope(caller)
    raw_schema = {base_url, sub_schema}
    schema = map_schema(raw_schema) |> List.flatten
    Module.put_attribute(caller.module, :schema, schema)

    quote do
      def __schema__ do
        raw_defs = @schema
        module = __MODULE__
        Enum.map(raw_defs, &unquote(@base_module).resolve_attributes/1)
      end
    end
  end

  defp new_scope(caller, attrs \\ []), do: %{
    @attributes_key => _attrs(caller, attrs),
  }

  defp push_scope(caller, scope) do
    current = Module.get_attribute(caller.module, @scope_stack_key)
    Module.put_attribute(caller.module, @scope_stack_key, [scope | current || []])
  end

  defp pop_scope(caller) do
    [current | rest] = Module.get_attribute(caller.module, @scope_stack_key)
    Module.put_attribute(caller.module, @scope_stack_key, rest)
    current
  end

  def pop_do_block!(caller, attrs) do
    result = {do_block, _} = Keyword.pop(attrs, :do)
    if !do_block do
      raise CompileError, description: "Missing :do block", file: caller.file, line: caller.line
    else
      result
    end
  end

  defp put_attribute(%{@attributes_key => attributes} = scope, key, value),
    do: put_attributes(scope, Keyword.put(attributes, key, value))
  defp put_attribute(scope, key, value), do: put_attributes(scope, Keyword.put([], key, value))
  defp put_attributes(scope, attr_list), do: Map.put(scope, @attributes_key, attr_list)
end
