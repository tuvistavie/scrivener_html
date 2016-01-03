defmodule Scrivener.HTML do
  use Phoenix.HTML
  @defaults [view_style: :bootstrap, action: :index]
  @raw_defaults [distance: 5, next: ">>", previous: "<<", first: true, last: true]
  @moduledoc """
  For use with Phoenix.HTML, configure the `:routes_helper` module like the following:

      config :scrivener_html,
        routes_helper: MyApp.Router.Helpers

  Import to you view.

      defmodule MyApp.UserView do
        use MyApp.Web, :view
        import Scrivener.HTML
      end

  Use in your template.

      <%= pagination_links @conn, @page %>

  Where `@page` is a `%Scrivener.Page{}` struct returned from `Repo.paginate/2`.

  Customize output. Below are the defaults.

      <%= pagination_links @conn, @page, distance: 5, next: ">>", previous: "<<", first: true, last: true %>

  See `Scrivener.HTML.raw_pagination_links/2` for option descriptions.

  For custom HTML output, see `Scrivener.HTML.raw_pagination_links/2`.
  """

  defmodule Default do
    @doc """
    Default path function when none provided. Used when automatic path function
    resolution cannot be performed.
    """
    def path(_conn, :index, opts) do
      Enum.reduce opts, "?", fn {k, v}, s ->
        "#{s}#{if(s == "?", do: "", else: "&")}#{k}=#{v}"
      end
    end
  end

  @doc """
  Generates the HTML pagination links for a given paginator returned by Scrivener.

  The default options are:

      #{inspect @defaults}

  The `view_style` indicates which CSS framework you are using. The default is
  `:bootstrap`, but you can add your own using the `Scrivener.HTML.raw_pagination_links/2` function
  if desired.

  An example of the output data:

      iex> Scrivener.HTML.pagination_links(%Scrivener.Page{total_pages: 10, page_number: 5})
      {:safe,
        ["<nav>",
         ["<ul class=\"pagination\">",
          [["<li>", ["<a class=\"\" href=\"?page=4\">", "&lt;&lt;", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=1\">", "1", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=2\">", "2", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=3\">", "3", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=4\">", "4", "</a>"], "</li>"],
           ["<li>", ["<a class=\"active\" href=\"?page=5\">", "5", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=6\">", "6", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=7\">", "7", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=8\">", "8", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=9\">", "9", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=10\">", "10", "</a>"], "</li>"],
           ["<li>", ["<a class=\"\" href=\"?page=6\">", "&gt;&gt;", "</a>"], "</li>"]],
          "</ul>"], "</nav>"]}

  In order to generate links with nested objects (such as a list of comments for a given post)
  it is necessary to pass those arguments. All arguments in the `args` parameter will be directly
  passed to the path helper function. Everything within `opts` which are not options will passed
  as `params` to the path helper function. For example, `@post`, which has an index of paginated
  `@comments` would look like the following:

      Scrivener.HTML.pagination_links(@conn, @comments, [@post], view_style: :bootstrap, my_param: "foo")

  You'll need to be sure to configure `:scrivener_html` with the `:routes_helper`
  module (ex. MyApp.Routes.Helpers) in Phoenix. With that configured, the above would generate calls
  to the `post_comment_path(@conn, :index, @post.id, my_param: "foo", page: page)` for each page link.

  In times that it is necessary to override the automatic path function resolution, you may supply the
  correct path function to use by adding an extra key in the `opts` parameter of `:path`.
  For example:

      Scrivener.HTML.pagination_links(@conn, @comments, [@post], path: &post_comment_path/4)

  Be sure to supply the function which accepts query string parameters (starts at arity 3, +1 for each relation),
  because the `page` parameter will always be supplied. If you supply the wrong function you will receive a
  function undefined exception.
  """
  def pagination_links(conn, paginator, args, opts) do
    opts = Dict.merge opts, view_style: opts[:view_style] || Application.get_env(:scrivener_html, :view_style, :bootstrap)
    merged_opts = Dict.merge @defaults, opts

    path = opts[:path] || find_path_fn(conn && paginator.entries, args)
    params = Dict.drop opts, (Dict.keys(@defaults) ++ [:path])

    # Ensure ordering so pattern matching is reliable
    _pagination_links paginator,
      view_style: merged_opts[:view_style],
      path: path,
      args: [conn, merged_opts[:action]] ++ args,
      params: params
  end
  def pagination_links(%Scrivener.Page{} = paginator), do: pagination_links(nil, paginator, [], [])
  def pagination_links(%Scrivener.Page{} = paginator, opts), do: pagination_links(nil, paginator, [], opts)
  def pagination_links(conn, %Scrivener.Page{} = paginator), do: pagination_links(conn, paginator, [], [])
  def pagination_links(conn, paginator, [{_, _} | _] = opts), do: pagination_links(conn, paginator, [], opts)
  def pagination_links(conn, paginator, [_ | _] = args), do: pagination_links(conn, paginator, args, [])

  defp find_path_fn(nil, _path_args), do: &Default.path/3
  defp find_path_fn([], _path_args), do: fn _, _, _ -> nil end
  # Define a different version of `find_path_fn` whenever Phoenix is available.
  if Code.ensure_loaded(Phoenix.Naming) do
    defp find_path_fn(entries, path_args) do
      routes_helper_module = Application.get_env(:scrivener_html, :routes_helper) || raise("Scrivener.HTML: Unable to find configured routes_helper module (ex. MyApp.Router.Helper)")
      path = (path_args) |> Enum.reduce(name_for(List.first(entries), ""), &name_for/2)
      {path_fn, []} = Code.eval_quoted(quote do: &unquote(routes_helper_module).unquote(:"#{path <> "_path"}")/unquote(length(path_args) + 3))
      path_fn
    end
  else
    defp find_path_fn(_entries, _args), do: &Default/3
  end

  defp name_for(model, acc) do
    "#{acc}#{if(acc != "", do: "_")}#{Phoenix.Naming.resource_name(model.__struct__)}"
  end

  # Bootstrap implementation
  defp _pagination_links(paginator, [view_style: :bootstrap, path: path, args: args, params: params]) do
    content_tag :nav do
      content_tag :ul, class: "pagination" do
        raw_pagination_links(paginator)
        |> Enum.map(fn ({text, page_number})->
          classes = []
          if paginator.page_number == page_number do
            classes = ["active"]
          end
          params_with_page = Dict.merge(params, page: page_number)
          class = Enum.join(classes, " ")
          content_tag :li, class: class do
            to = apply(path, args ++ [params_with_page])
            if to do
              link "#{text}", to: apply(path, args ++ [params_with_page])
            else
              content_tag :a, "#{text}"
            end
          end
        end)
      end
    end
  end

  defp _pagination_links(_paginator, [view_style: unknown, path: _path, args: _args, params: _params]) do
    raise "Scrivener.HTML: Unable to render view_style #{inspect unknown}"
  end

  @doc """
  Returns the raw data in order to generate the proper HTML for pagination links. Data
  is returned in a `{text, page_number}` format where `text` is intended to be the text
  of the link and `page_number` is the page it should go to. Defaults are already supplied
  and they are as follows:

      #{inspect @raw_defaults}

  `distance` must be a positive non-zero integer or an exception is raised. `next` and `previous` should be
  strings but can be anything you want as long as it is truthy, falsey values will remove
  them from the output. `first` and `last` are only booleans, and they just include/remove
  their respective link from output. An example of the data returned:

      iex> Scrivener.HTML.raw_pagination_links(%{total_pages: 10, page_number: 5})
      [{"<<", 4}, {1, 1}, {2, 2}, {3, 3}, {4, 4}, {5, 5}, {6, 6}, {7, 7}, {8, 8}, {9, 9}, {10, 10}, {">>", 6}]

  Simply loop and pattern match over each item and transform it to your custom HTML.
  """
  def raw_pagination_links(paginator, options \\ []) do
    options = Dict.merge @raw_defaults, options
    page_number_list(paginator.page_number, paginator.total_pages, options[:distance])
    |> add_first(paginator.page_number, options[:distance], options[:first])
    |> add_previous(paginator.page_number)
    |> add_last(paginator.page_number, paginator.total_pages, options[:distance], options[:last])
    |> add_next(paginator.page_number, paginator.total_pages)
    |> Enum.map(fn
      :next -> if options[:next], do: {options[:next], paginator.page_number + 1}
      :previous -> if options[:previous], do: {options[:previous], paginator.page_number - 1}
      num -> {num, num}
    end) |> Enum.filter(&(&1))
  end

  # Computing page number ranges
  defp page_number_list(page, total, distance) when is_integer(distance) and distance >= 1 do
    Enum.to_list((page - beginning_distance(page, distance))..(page + end_distance(page, total, distance)))
  end
  defp page_number_list(_page, _total, _distance) do
    raise "Scrivener.HTML: Distance cannot be less than one."
  end

  # Beginning distance computation
  defp beginning_distance(page, distance) when page - distance < 1 do
    distance + (page - distance - 1)
  end
  defp beginning_distance(_page, distance) do
    distance
  end

  # End distance computation
  defp end_distance(_page, 0, _distance) do
    0
  end
  defp end_distance(page, total, distance) when page + distance >= total do
    total - page
  end
  defp end_distance(_page, _total, distance) do
    distance
  end

  # Adding next/prev/first/last links
  defp add_previous(list, page) when page != 1 do
    [:previous] ++ list
  end
  defp add_previous(list, _page) do
    list
  end

  defp add_first(list, page, distance, true) when page - distance > 1 do
    [1] ++ list
  end
  defp add_first(list, _page, _distance, _included) do
    list
  end

  defp add_last(list, page, total, distance, true) when page + distance < total do
    list ++ [total]
  end
  defp add_last(list, _page, _total, _distance, _included) do
    list
  end

  defp add_next(list, page, total) when page != total and page < total do
    list ++ [:next]
  end
  defp add_next(list, _page, _total) do
    list
  end

end

# Must do this until Scrivener adds @derive [Enumerable, Access]
defimpl Enumerable, for: Scrivener.Page do
  def reduce(pages, acc, fun), do: Enum.reduce(pages.entries || [], acc, fun)
  def member?(pages, page), do: page in pages.entries
  def count(pages), do: length(pages.entries)
end
