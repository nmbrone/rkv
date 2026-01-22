defmodule RkvTest do
  use ExUnit.Case, async: true

  setup do
    bucket = :kv_test
    start_link_supervised!({Rkv, bucket: bucket})
    [bucket: bucket]
  end

  describe "start_link/1" do
    test "checks the table protection" do
      assert_raise RuntimeError, ~r/Rkv: table must be :public/, fn ->
        start_supervised!({Rkv, bucket: :foo, ets_options: []})
      end
    end

    test "checks the table type" do
      assert_raise RuntimeError, ~r/Rkv: table must be :set or :ordered_set/, fn ->
        start_supervised!({Rkv, bucket: :foo, ets_options: [:bag]})
      end

      assert_raise RuntimeError, ~r/Rkv: table must be :set or :ordered_set/, fn ->
        start_supervised!({Rkv, bucket: :foo, ets_options: [:duplicate_bag]})
      end
    end
  end

  describe "all/1" do
    test "gets all values", %{bucket: bucket} do
      assert Rkv.all(bucket) == []
      Rkv.put(bucket, "a", 1)
      Rkv.put(bucket, "b", 2)
      assert bucket |> Rkv.all() |> Enum.sort() == [{"a", 1}, {"b", 2}]
    end
  end

  describe "get/2" do
    test "gets the value", %{bucket: bucket} do
      assert Rkv.get(bucket, :foo) == nil
      assert Rkv.put(bucket, :foo, "bar") == :ok
      assert Rkv.get(bucket, :foo) == "bar"
    end

    test "returns the default", %{bucket: bucket} do
      assert Rkv.get(bucket, :foo, "baz") == "baz"
    end
  end

  describe "fetch/2" do
    test "returns the error if the key does not exist", %{bucket: bucket} do
      assert :error = Rkv.fetch(bucket, :foo)
    end

    test "returns the value", %{bucket: bucket} do
      :ok = Rkv.put(bucket, :foo, "bar")
      assert {:ok, "bar"} = Rkv.fetch(bucket, :foo)
    end
  end

  describe "put/3" do
    test "puts the value", %{bucket: bucket} do
      assert Rkv.put(bucket, :foo, "bar") == :ok
      assert Rkv.get(bucket, :foo) == "bar"
    end
  end

  describe "put_new/3" do
    test "puts the value if the key does not exist", %{bucket: bucket} do
      :ok = Rkv.watch_all(bucket)
      assert Rkv.put_new(bucket, :foo, "bar") == :ok
      assert Rkv.get(bucket, :foo) == "bar"
      assert_received {:updated, ^bucket, :foo}
    end

    test "returns the error if the key already exists", %{bucket: bucket} do
      :ok = Rkv.put(bucket, :foo, "bar")
      :ok = Rkv.watch_all(bucket)
      assert Rkv.put_new(bucket, :foo, "baz") == {:error, :already_exists}
      assert Rkv.get(bucket, :foo) == "bar"
      refute_received {:updated, ^bucket, :foo}
    end
  end

  describe "delete/2" do
    test "deletes the value", %{bucket: bucket} do
      Rkv.put(bucket, :foo, "bar")
      assert Rkv.delete(bucket, :foo) == :ok
      assert Rkv.get(bucket, :foo) == nil
    end
  end

  describe "exists?" do
    test "returns false when key does not exist", %{bucket: bucket} do
      assert Rkv.exists?(bucket, :foo) == false
    end

    test "returns true when key exists", %{bucket: bucket} do
      Rkv.put(bucket, :foo, "bar")
      assert Rkv.exists?(bucket, :foo) == true
    end
  end

  describe "watch_key/2" do
    test "subscribes to key updates", %{bucket: bucket} do
      assert :ok = Rkv.watch_key(bucket, :foo)

      Rkv.put(bucket, :foo, "bar")
      assert_receive {:updated, ^bucket, :foo}

      Rkv.put(bucket, :bar, "baz")
      refute_receive {:updated, ^bucket, :bar}

      Rkv.delete(bucket, :foo)
      assert_receive {:deleted, ^bucket, :foo}

      Rkv.delete(bucket, :bar)
      refute_receive {:deleted, ^bucket, :bar}
    end
  end

  describe "watch_all/1" do
    test "subscribes to all updates", %{bucket: bucket} do
      assert :ok = Rkv.watch_all(bucket)

      Rkv.put(bucket, :foo, "bar")
      assert_receive {:updated, ^bucket, :foo}

      Rkv.put(bucket, :bar, "baz")
      assert_receive {:updated, ^bucket, :bar}

      Rkv.delete(bucket, :foo)
      assert_receive {:deleted, ^bucket, :foo}

      Rkv.delete(bucket, :bar)
      assert_receive {:deleted, ^bucket, :bar}
    end
  end

  describe "unwatch_key/1" do
    test "unsubscribes from key updates", %{bucket: bucket} do
      assert :ok = Rkv.watch_key(bucket, :foo)
      assert :ok = Rkv.unwatch_key(bucket, :foo)

      Rkv.put(bucket, :foo, "bar")
      refute_receive {:updated, ^bucket, :foo}
    end
  end

  describe "unwatch_all/1" do
    test "unsubscribes from all updates", %{bucket: bucket} do
      assert :ok = Rkv.watch_all(bucket)
      assert :ok = Rkv.unwatch_all(bucket)

      Rkv.put(bucket, :foo, "bar")
      refute_receive {:updated, ^bucket, :foo}
    end
  end
end
