defmodule GangWeb.CardUtilsTest do
  use ExUnit.Case, async: true

  alias GangWeb.CardUtils

  doctest CardUtils

  describe "pluralize_rank/1" do
    test "handles singular face cards (primary use case)" do
      assert CardUtils.pluralize_rank("King") == "Kings"
      assert CardUtils.pluralize_rank("Queen") == "Queens"
      assert CardUtils.pluralize_rank("Jack") == "Jacks"
      assert CardUtils.pluralize_rank("Ace") == "Aces"
    end

    test "handles already plural face cards (backward compatibility)" do
      assert CardUtils.pluralize_rank("Kings") == "Kings"
      assert CardUtils.pluralize_rank("Queens") == "Queens"
      assert CardUtils.pluralize_rank("Jacks") == "Jacks"
      assert CardUtils.pluralize_rank("Aces") == "Aces"
    end

    test "handles numeric ranks" do
      assert CardUtils.pluralize_rank("2") == "2s"
      assert CardUtils.pluralize_rank("3") == "3s"
      assert CardUtils.pluralize_rank("10") == "10s"
    end

    test "fixes the original issue with Kings" do
      # This was the original bug: "Kings" + "s" = "Kingss"
      # Now it should stay as "Kings"
      assert CardUtils.pluralize_rank("Kings") == "Kings"
      assert CardUtils.pluralize_rank("King") == "Kings"
    end

    test "handles edge cases" do
      assert CardUtils.pluralize_rank("4") == "4s"
      assert CardUtils.pluralize_rank("9") == "9s"
    end
  end
end
