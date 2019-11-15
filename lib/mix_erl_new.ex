defmodule Mix.Tasks.Erl.New do
  use Mix.Task

  import Mix.Generator

  @shortdoc "Creates a new Erlang project"

  @moduledoc """
  Creates a new Erlang project.
  It expects the path of the project as argument.

      mix erl.new PATH [--app APP] [--module MODULE] [--sup]

  A project at the given PATH will be created. The
  application name and module name will be generated
  from the path, unless `--module` or `--app` is given.

  An `--app` option can be given in order to
  name the OTP application for the project.

  A `--module` option can be given in order
  to name the modules in the generated code skeleton.

  A `--sup` option can be given to generate an OTP application
  skeleton including a supervision tree. Normally an app is
  generated without a supervisor and without the app callback.
  """

  @switches [
    app: :string,
    module: :string,
    sup: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)
    case argv do
      [] ->
        Mix.raise("Expected PATH to be given, please use \"mix erl.new PATH\"")

      [path | _] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        mod = opts[:module] || app

        unless path == "." do
          check_directory_existence!(path)
          File.mkdir_p!(path)
        end

        File.cd!(path, fn ->
          generate(app, mod, path, opts)
        end)
    end
  end

  defp generate(app, mod, path, opts) do
    assigns = [
      app: app,
      mod: mod,
      path: path,
      project: Macro.camelize(app),
      version: "0.1.0",
      sup: opts[:sup]
    ]

    create_file("README.md", readme_template(assigns))
    create_file("mix.exs", mix_exs_template(assigns))

    create_directory("src")
    create_file("src/#{mod}.erl", mod_template(assigns))

    if opts[:sup] do
      create_file("src/#{app}_app.erl", app_template(assigns))
      create_file("src/#{app}_sup.erl", sup_template(assigns))
    end
  end

  defp check_directory_existence!(path) do
    msg = "The directory #{inspect(path)} already exists. Are you sure you want to continue?"

    if File.dir?(path) and not Mix.shell().yes?(msg) do
      Mix.raise("Please select another directory for installation")
    end
  end

  embed_template(:readme, """
  mix compile
  ERL_LIBS=_build/dev/lib/ erl
  """)

  embed_template(:mix_exs, """
  defmodule <%= @project %>.MixProject do
    use Mix.Project

    def project do
      [
        app: :<%= @app %>,
        version: "<%= @version %>",
        language: :erlang,
        erlc_options: erlc_options(),
        deps: deps()
      ]
    end

    <%= if @sup do %>
    def application do
      [
        mod: {:<%= @app %>_app, []}
      ]
    end
    <% end %>

    defp erlc_options do
      [
        :debug_info,
        :warnings_as_errors
      ]
    end

    defp deps do
      [
        # {:dep_from_hexpm, "~> 0.3.0"},
        # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
        # {:sibling_app_in_umbrella, in_umbrella: true}
      ]
    end
  end
  """)

  embed_template(:mod, """
  -module(<%= @mod %>).
  -export([hello/0]).

  hello() ->
      world.
  """)

  embed_template(:app, """
  -module(<%= @app %>_app).
  -behaviour(application).
  -export([start/2, stop/1]).

  start(_Type, _Args) ->
      <%= @app %>_sup:start_link().

  stop(_State) ->
      ok.
  """)

  embed_template(:sup, ~S"""
  -module(<%= @app %>_sup).
  -export([start_link/0]).
  -behaviour(supervisor).
  -export([init/1]).

  start_link() ->
      supervisor:start_link(?MODULE, []).

  init([]) ->
      Flags = #{strategy => one_for_one, intensity => 1, period => 5},
      Children = [],
      {ok, {Flags, Children}}.
  """)
end
