defmodule BlammoWeb.Router do
  use BlammoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BlammoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BlammoWeb do
    pipe_through :browser
    live "/", LogViewerLive
  end

  scope "/api", BlammoWeb do
    pipe_through :api
    get "/tagline", LogsController, :tagline
    get "/logs", LogsController, :logs
    get "/logs/tail", LogsController, :loglines
    get "/servers", ServersController, :index
    get "/servers/logs", ServersController, :logs
    get "/servers/logs/filter-first", ServersController, :filter_first
    get "/servers/logs/tail-first", ServersController, :tail_first
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:blammo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BlammoWeb.Telemetry
      # forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
