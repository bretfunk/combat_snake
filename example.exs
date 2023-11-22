Mix.install([
  {:bumblebee, git: "https://github.com/toranb/bumblebee", branch: "main"},
  {:nx, "~> 0.6.2", override: true},
  {:exla, "~> 0.6.1"},
  {:plug_cowboy, "~> 2.6"},
  {:jason, "~> 1.4"},
  {:phoenix, "~> 1.7"},
  {:phoenix_live_view, "~> 0.20.0"}
])

Application.put_env(:phoenix, :json_library, Jason)

Application.put_env(:phoenix_demo, PhoenixDemo.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4200],
  check_origin: false,
  server: true,
  live_view: [signing_salt: :crypto.strong_rand_bytes(8) |> Base.encode16()],
  secret_key_base: :crypto.strong_rand_bytes(32) |> Base.encode16(),
  pubsub_server: PhoenixDemo.PubSub
)

defmodule PhoenixDemo.Layouts do
  use Phoenix.Component

  def render("live.html", assigns) do
    ~H"""
    <script src="//cdn.jsdelivr.net/npm/phoenix@1.7.6/priv/static/phoenix.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/phoenix_live_view@0.20.0/priv/static/phoenix_live_view.min.js"></script>
    <script>
      const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {hooks: {}})
      liveSocket.connect()
    </script>
    <script src="https://cdn.tailwindcss.com"></script>
    <%= @inner_content %>
    """
  end
end

defmodule PhoenixDemo.ErrorView do
  def render(_, _), do: "error"
end

defmodule PhoenixDemo.SampleLive do
  use Phoenix.LiveView, layout: {PhoenixDemo.Layouts, :live}

  alias Phoenix.LiveView.AsyncResult

  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-screen flex items-center justify-center antialiased bg-gray-100 px-5">
      <div class="flex flex-col items-center w-full">
        <h1 class="text-slate-900 font-extrabold text-3xl tracking-tight text-center">
          Elixir and Zephyr running on the RTX 4090
        </h1>
        <p class="mt-6 text-lg text-slate-600 text-center max-w-4xl mx-auto">
          Powered by <a href="https://github.com/elixir-nx/bumblebee" class="font-mono font-medium text-sky-500">Bumblebee</a>,
          an Nx/Axon library for pre-trained and transformer NN models with <a href="https://huggingface.co">🤗</a> integration.
        </p>
        <div class="mt-6 w-full mx-auto">
          <form phx-submit="generate" class="space-y-5 max-w-4xl mx-auto">
            <div class="relative">
              <label for="prompt" class="block text-lg md:text-base font-medium leading-6 text-gray-900">Prompt</label>
              <div class="mt-2">
                <textarea
                  id="prompt"
                  name="prompt"
                  rows="4"
                  class="block w-full rounded-md border-0 p-2 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 text-lg sm:text-base leading-6"
                ><%= @prompt %></textarea>
              </div>
              <button disabled={!!@output.loading} type="submit" class="absolute bottom-1 right-1 rounded-md bg-indigo-600 px-3 py-2 text-lg md:text-base font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600">
                Generate
                <.spinner :if={@output.loading} />
              </button>
            </div>
            <p id="output" phx-update="stream" class="text-xl sm:text-base py-5">
              <span :for={{id, segment} <- @streams.output} id={id}><%= segment.content %></span>
            </p>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:output, [])
     |> assign(
       prompt: nil,
       output: AsyncResult.ok(AsyncResult.loading(), [])
     )}
  end

  def handle_event("validate", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, prompt: prompt)}
  end

  def handle_event("generate", %{"prompt" => prompt}, socket) do
    parent = self()

    {:noreply,
     socket
     |> assign(prompt: prompt, output: AsyncResult.loading())
     |> stream(:output, [], reset: true)
     |> cancel_async(:output)
     |> start_async(:output, fn ->
       for {segment, index} <- Stream.with_index(Nx.Serving.batched_run(MistralServing, prompt)) do
         send(parent, {:output, {segment, index}})
       end
     end)}
  end

  def handle_info({:output, {segment, index}}, socket) do
    {:noreply, stream(socket, :output, [%{id: "s-#{index}", content: segment}])}
  end

  def handle_async(:output, {:ok, _}, socket) do
    {:noreply, assign(socket, :output, AsyncResult.ok(socket.assigns.output, []))}
  end

  defp spinner(assigns) do
    ~H"""
    <svg phx-no-format class="inline ml-1 w-4 h-4 text-gray-200 animate-spin fill-blue-600" viewBox="0 0 100 101" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z" fill="currentColor" />
      <path d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z" fill="currentFill" />
    </svg>
    """
  end
end

defmodule PhoenixDemo.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", PhoenixDemo do
    pipe_through(:browser)

    live("/", SampleLive, :index)
  end
end

defmodule PhoenixDemo.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_demo

  socket("/live", Phoenix.LiveView.Socket)
  plug(PhoenixDemo.Router)
end

# Application startup

Nx.default_backend(EXLA.Backend)
# Nx.global_default_backend(EXLA.Backend)

Application.put_env(:exla, :clients,
  cuda: [platform: :cuda, preallocate: false],
  rocm: [platform: :rocm, preallocate: false],
  tpu: [platform: :tpu, preallocate: false],
  host: [platform: :host, preallocate: false]
)

mistral = {:hf, "HuggingFaceH4/zephyr-7b-beta"}
{:ok, spec} = Bumblebee.load_spec(mistral, module: Bumblebee.Text.Mistral, architecture: :for_causal_language_modeling)
{:ok, model_info} = Bumblebee.load_model(mistral, spec: spec, backend: {EXLA.Backend, client: :host})
{:ok, tokenizer} = Bumblebee.load_tokenizer(mistral, module: Bumblebee.Text.LlamaTokenizer)
{:ok, generation_config} = Bumblebee.load_generation_config(mistral, spec_module: Bumblebee.Text.Mistral)

generation_config = Bumblebee.configure(generation_config, max_new_tokens: 500, no_repeat_ngram_length: 5, strategy: %{type: :multinomial_sampling, top_p: 0.6})

serving = Bumblebee.Text.generation(model_info, tokenizer, generation_config, stream: true, defn_options: [compiler: EXLA])

{:ok, _} =
  Supervisor.start_link(
    [
      {Phoenix.PubSub, name: PhoenixDemo.PubSub},
      {Nx.Serving, serving: serving, name: MistralServing},
      PhoenixDemo.Endpoint
    ],
    strategy: :one_for_one
  )

Process.sleep(:infinity)
