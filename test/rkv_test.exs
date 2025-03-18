defmodule RkvTest do
  use ExUnit.Case, async: true

  setup do
    name = :kv_test
    start_link_supervised!({Rkv, name: name})
    [kv: name]
  end

  describe "start_link/1" do
    test "checks the table protection" do
      assert_raise RuntimeError, ~r/Rkv: table must be :public/, fn ->
        start_supervised!({Rkv, name: :foo, ets_options: []})
      end
    end

    test "checks the table type" do
      assert_raise RuntimeError, ~r/Rkv: table must be :set or :ordered_set/, fn ->
        start_supervised!({Rkv, name: :foo, ets_options: [:bag]})
      end

      assert_raise RuntimeError, ~r/Rkv: table must be :set or :ordered_set/, fn ->
        start_supervised!({Rkv, name: :foo, ets_options: [:duplicate_bag]})
      end
    end
  end

  describe "all/1" do
    test "gets all values", %{kv: kv} do
      assert Rkv.all(kv) == []
      Rkv.put(kv, "a", 1)
      Rkv.put(kv, "b", 2)
      assert Rkv.all(kv) == [{"b", 2}, {"a", 1}]
    end
  end

  describe "get/2" do
    test "gets the value", %{kv: kv} do
      assert Rkv.get(kv, :foo) == nil
      assert Rkv.put(kv, :foo, "bar") == :ok
      assert Rkv.get(kv, :foo) == "bar"
    end

    test "returns the default", %{kv: kv} do
      assert Rkv.get(kv, :foo, "baz") == "baz"
    end
  end

  describe "put/2" do
    test "puts the value", %{kv: kv} do
      assert Rkv.put(kv, :foo, "bar") == :ok
      assert Rkv.get(kv, :foo) == "bar"
    end
  end

  describe "del/2" do
    test "deletes the value", %{kv: kv} do
      Rkv.put(kv, :foo, "bar")
      assert Rkv.del(kv, :foo) == :ok
      assert Rkv.get(kv, :foo) == nil
    end
  end

  describe "watch_key/2" do
    test "subscribes to key updates", %{kv: kv} do
      assert :ok = Rkv.watch_key(kv, :foo)

      Rkv.put(kv, :foo, "bar")
      assert_receive {Rkv, :updated, ^kv, :foo}

      Rkv.put(kv, :bar, "baz")
      refute_receive {Rkv, :updated, ^kv, :bar}

      Rkv.del(kv, :foo)
      assert_receive {Rkv, :deleted, ^kv, :foo}

      Rkv.del(kv, :bar)
      refute_receive {Rkv, :deleted, ^kv, :bar}
    end
  end

  describe "watch_all/1" do
    test "subscribes to all updates", %{kv: kv} do
      assert :ok = Rkv.watch_all(kv)

      Rkv.put(kv, :foo, "bar")
      assert_receive {Rkv, :updated, ^kv, :foo}

      Rkv.put(kv, :bar, "baz")
      assert_receive {Rkv, :updated, ^kv, :bar}

      Rkv.del(kv, :foo)
      assert_receive {Rkv, :deleted, ^kv, :foo}

      Rkv.del(kv, :bar)
      assert_receive {Rkv, :deleted, ^kv, :bar}
    end
  end

  describe "unwatch_key/1" do
    test "unsubscribes from key updates", %{kv: kv} do
      assert :ok = Rkv.watch_key(kv, :foo)
      assert :ok = Rkv.unwatch_key(kv, :foo)

      Rkv.put(kv, :foo, "bar")
      refute_receive {Rkv, :updated, ^kv, :foo}
    end
  end

  describe "unwatch_all/1" do
    test "unsubscribes from all updates", %{kv: kv} do
      assert :ok = Rkv.watch_all(kv)
      assert :ok = Rkv.unwatch_all(kv)

      Rkv.put(kv, :foo, "bar")
      refute_receive {Rkv, :updated, ^kv, :foo}
    end
  end
end
