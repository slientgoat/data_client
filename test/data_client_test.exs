defmodule DataClientTest do
  use ExUnit.Case
  doctest DataClient
  import ShorterMaps
  @api "http://192.168.11.2:8080/events"

  setup_all do
    {:ok, pid} = DataClient.start_link(block_id: 1, api: @api)
    %{pid: pid}
  end

  test "test login", _state do
    content = ~m{account: "acc001",role_name: "acc001",pass_type: 1}
    assert DataClient.post(@api, "login", content) == {:ok, "ok"}
  end

  test "test battle_record", _state do
    content = ~m{account: "acc001",battle_id: "1",battle_type: 1,battle_result: 0}
    assert DataClient.post(@api, "battle_record", content) == {:ok, "ok"}

    content = ~m{account: "acc001",battle_id: "2",battle_type: 1,battle_result: 1}
    assert DataClient.post(@api, "battle_record", content) == {:ok, "ok"}

    content = ~m{account: "acc001",battle_id: "3",battle_type: 2,battle_result: 1}
    assert DataClient.post(@api, "battle_record", content) == {:ok, "ok"}
  end

  test "test weapon_record", _state do
    content =
      ~m{account: "acc001",weapon_id: 10010101,weapon_type: 1,weapon_quality: 1,weapon_abrasion: 0.0}

    assert DataClient.post(@api, "weapon_record", content) == {:ok, "ok"}

    content =
      ~m{account: "acc001",weapon_id: 10120103,weapon_type: 4,weapon_quality: 4,weapon_abrasion: 0.6860733087445781}

    assert DataClient.post(@api, "weapon_record", content) == {:ok, "ok"}
  end

  test "test box_count", _state do
    content = ~m{account: "acc001",box_count: 1}
    assert DataClient.post(@api, "box_num", content) == {:ok, "ok"}

    content = ~m{account: "acc001",box_count: 2}
    assert DataClient.post(@api, "box_num", content) == {:ok, "ok"}

    content = ~m{account: "acc001",box_count: 1}
    assert DataClient.post(@api, "box_num", content) == {:ok, "ok"}
  end
end
