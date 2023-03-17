defmodule DataClient do
  use GenServer
  require Logger
  import ShorterMaps

  @inteval 50

  defstruct index: 0, reports: [], api: nil, req_id: 0, block_id: 1
  alias DataClient, as: M

  def t() do
    DataClient.start_link(block_id: 1, api: "http://192.168.11.2:8080/events")
  end

  def log_login(unixtime, account, role_name, pass_type) do
    push("login", unixtime, ~m{account,role_name,pass_type})
  end

  def log_battle_record(unixtime, account, battle_id, battle_type, battle_result) do
    push("battle_record", unixtime, ~m{account, battle_id, battle_type, battle_result})
  end

  def log_weapon_record(
        unixtime,
        account,
        weapon_id,
        weapon_type,
        weapon_quality,
        weapon_abrasion
      ) do
    push(
      "weapon_record",
      unixtime,
      ~m{account, weapon_id, weapon_type, weapon_quality,weapon_abrasion}
    )
  end

  def log_box_num(unixtime, account, box_count) do
    push("box_num", unixtime, ~m{account, box_count})
  end

  def make_req_id(block_id, unixtime, index) when block_id > 0 and block_id < 10000 do
    index =
      if index < 9999 do
        index + 1
      else
        1
      end

    temp = "#{block_id}#{unixtime}" |> String.to_integer()
    {temp * 1000 + index, index}
  end

  def submit(pid, report, api) do
    {event, data} = Map.pop(report, "event")

    spawn(fn ->
      with {:ok, req_id} <- post(api, event, data) do
        send(pid, {:ack, req_id})
      else
        reason ->
          Logger.error("submit fail #{inspect(%{api: api, report: report, reason: reason})}")
      end
    end)

    :ok
  end

  def post(api, event, data) do
    content = %{event: event, data: data} |> Jason.encode!()

    api
    |> HTTPoison.post(content, ["Content-Type": "application/json"], recv_timeout: 5000)
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200, body: req_id}} ->
        {:ok, req_id}

      {:ok, %HTTPoison.Response{status_code: 400, body: body}} ->
        {:bad_request, body}

      {:ok, %HTTPoison.Response{status_code: 404, body: body}} ->
        {:not_found, body}

      {:ok, %HTTPoison.Response{status_code: 500}} ->
        :server_error

      {:error, %HTTPoison.Error{reason: :econnrefused}} ->
        :econnrefused

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:unkonwn, reason}
    end
  end

  @spec push(event :: binary(), unixtime :: non_neg_integer(), data :: map()) :: :ok
  def push(event, unixtime, data) do
    GenServer.cast(__MODULE__, {:push, Map.put(data, "event", event), unixtime})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    api = Keyword.get(opts, :api, System.get_env("DATA_SERVER_API"))
    if !(api != "" and api != nil), do: raise("System Env 'DATA_SERVER_API' is not set")
    if !valid_url?(api), do: raise("System env 'DATA_SERVER_API=#{api}' is not valid")
    block_id = Keyword.get(opts, :block_id, 1)
    reports = LimitedQueue.new(100_000)
    send(self(), :loop)
    {:ok, %M{reports: reports, api: api, block_id: block_id}}
  end

  @impl true
  def handle_call(_, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:push, report, _now}, state) do
    %M{reports: reports} = state
    Logger.debug("push #{inspect(report)} to data client.")
    # {req_id, index} = make_req_id(block_id, now, index)
    # report = Map.put(report, "req_id", req_id)
    reports = LimitedQueue.push(reports, report)
    {:noreply, %{state | reports: reports}}
  end

  @impl true
  def handle_info(:loop, %M{reports: reports, api: api} = state) do
    with {:ok, reports, report} <- LimitedQueue.pop(reports),
         :ok <- submit(self(), report, api) do
      Logger.debug("[#{inspect(self())}] submit #{inspect(report)} to data server.")
      Process.send_after(self(), :loop, @inteval)
      {:noreply, %{state | reports: reports}}
    else
      {:error, :empty} ->
        Process.send_after(self(), :loop, 1000)
        {:noreply, state}

      :econnrefused ->
        Process.send_after(self(), :loop, @inteval)
        {:noreply, state}

      reason ->
        Logger.error("push to data server fail for reason: #{inspect(reason)}")
        Process.send_after(self(), :loop, @inteval)
        {:noreply, state}
    end
  end

  def handle_info({:ack, req_id}, %M{} = state) do
    {:noreply, %{state | req_id: req_id}}
  end

  def valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme != nil && uri.host != ""
  end
end
