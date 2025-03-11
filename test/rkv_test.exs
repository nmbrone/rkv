defmodule RkvTest do
  use ExUnit.Case, async: true

  setup do
    start_link_supervised!({Rkv, name: :kv_test})
    [kv: :kv_test]
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

  describe "subscribe/2" do
    test "subscribes the caller", %{kv: kv} do
      assert Rkv.subscribe(kv, "foo") == :ok
      Rkv.put(kv, "foo", "bar")
      Rkv.del(kv, "foo")
      assert_receive {:kv, :add, ^kv, "foo"}
      assert_receive {:kv, :del, ^kv, "foo"}
    end
  end

  describe "unsubscribe/2" do
    test "unsubscribes the caller", %{kv: kv} do
      Rkv.subscribe(kv, "foo")
      Rkv.put(kv, "foo", "bar")
      assert_receive {:kv, :add, ^kv, "foo"}
      assert Rkv.unsubscribe(kv, "foo") == :ok
      Rkv.put(kv, "foo", "baz")
      refute_receive {:kv, :add, ^kv, "foo"}
    end
  end
end
