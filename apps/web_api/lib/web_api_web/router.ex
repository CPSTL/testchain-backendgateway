defmodule WebApiWeb.Router do
  use WebApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WebApiWeb do
    match :*, "/", IndexController, :index
    match :*, "/version", ChainController, :version
  end

  scope "/", WebApiWeb do
    pipe_through :api
    post "/rpc", InternalController, :rpc
    get "/chains", ChainController, :chain_list
    get "/snapshots/:chain", ChainController, :snapshot_list
    get "/snapshot/:id", ChainController, :download_snapshot
  end

  scope "/deployment", WebApiWeb do
    pipe_through :api
    get "/steps", DeploymentController, :steps
    # This is tmp route for testing only !
    post "/steps/reload", DeploymentController, :reload
  end

  scope "/chain", WebApiWeb do
    pipe_through :api
    delete "/:id", ChainController, :remove_chain
    get "/:id", ChainController, :details
  end
end
