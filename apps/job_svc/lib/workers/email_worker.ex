defmodule JobService.Workers.EmailWorker do
  @moduledoc """
  Oban worker for sending emails asynchronously via EmailService.

  This worker:
  1. Receives email job from Oban queue
  2. Calls EmailService to send the email
  3. Notifies JobService about delivery status via callback
  """

  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    priority: 1

  require Logger

  alias JobService.Clients.EmailSvcClient

  @impl Oban.Worker

  @spec perform(Oban.Job.t()) :: :ok | {:error, any()}
  def perform(%Oban.Job{args: %{"type" => "welcome"} = args}) do
    Logger.info("[EmailWorker] Sending #{args["type"]} email to user #{args["id"]}")
    EmailSvcClient.send_email(args)
  end

  def perform(%Oban.Job{args: %{"type" => "notification"} = args}) do
    Logger.info("[EmailWorker] Sending notification email to user #{args["user_id"]}")
    EmailSvcClient.send_email(args)
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("[EmailWorker] Unknown email type: #{inspect(args)}")
    {:error, "Unknown email type"}
  end
end
