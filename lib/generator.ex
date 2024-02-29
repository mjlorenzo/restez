defmodule RESTez.Client do

  @default_parameter_regex ~r/(\{.+?\})/
  @default_inner_regex ~r/\{(.*?)\}/

  @callback endpoint(id :: atom(), attr :: map(), url :: binary(), params :: map(), opts :: list()) :: term()
  @callback validate_param(key :: any(), value :: any()) :: boolean()
  @optional_callbacks validate_param: 2

  defmacro raise_if_no_schema(opts) do
    quote do
      schema = Keyword.get(unquote(opts), :schema)
      if !schema, do: raise CompileError, description: "Missing :schema in #{__CALLER__}", file: __CALLER__.file, line: __CALLER__.line
    end
  end

  defmacro __using__(opts) do
    raise_if_no_schema(opts)

    schema = opts[:schema]
    module = Macro.expand(schema, __ENV__)
    defs = module.__schema__() |> Enum.map(fn d -> Keyword.new(d) end)

    parameter_regex = opts[:parameter_regex] || @default_parameter_regex
    inner_regex = opts[:inner_regex] || @default_inner_regex

    interpolater = Keyword.get(opts, :interpolater) || &RESTez.Schema.interpolate_url/4

    endpoints = Enum.map(defs, fn d ->
      {id, attrs} = Keyword.pop!(d, :id)
      path = d[:path_template]
      quote bind_quoted: [interpolater: interpolater, id: id, attrs: attrs, path: path] do
        def unquote(id)(params, opts \\ []) do
          case unquote(interpolater).(unquote(path), params) do
            {:ok, url} ->
              endpoint(unquote(id), unquote(attrs), url, params, opts)
            {:error, error} ->
              {:error, error}
            error ->
              {:error, error}
          end
        end
      end
    end)

    quote do
      @behaviour unquote(__MODULE__)

      @parameter_regex unquote(Macro.escape(parameter_regex))
      @inner_regex unquote(Macro.escape(inner_regex))

      defp validate_params(params, url) do
        required = Rule.Val.Schema.get_required_params(url, @parameter_regex, @inner_regex)
        required_validated? = Enum.all?(required, &(params[&1]))
        Enum.reduce_while(params, required_validated?, fn p, acc ->
          still_valid? = acc and validate_param(p)
          if still_valid?, do: {:cont, true}, else: {:halt, false}
        end)
      end

      defp validate_param({_k, _v}), do: true

      unquote(endpoints)
    end
  end
end
