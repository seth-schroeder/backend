defmodule Cambiatus.Workers.MonthlyDigestWorkerTest do
  use Cambiatus.DataCase
  use Oban.Testing, repo: Cambiatus.Repo

  import Swoosh.TestAssertions

  alias Cambiatus.Workers.MonthlyDigestWorker

  describe "perform/1" do
    test "sends emails to all users from all communities with news" do
      community1 = insert(:community, has_news: true)
      community2 = insert(:community, has_news: true)
      community3 = insert(:community, has_news: false)
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      user4 = insert(:user)
      insert(:network, user: user1, community: community1)
      insert(:network, user: user2, community: community1)
      insert(:network, user: user3, community: community2)
      insert(:network, user: user4, community: community3)
      insert(:news, community: community1)
      insert(:news, community: community2)
      user4_email = user4.email

      assert :ok == perform_job(MonthlyDigestWorker, %{})

      assert_email_sent(
        to: user1.email,
        from: {"#{community1.name} - Cambiatus", "no-reply@cambiatus.com"},
        subject: "Community News"
      )

      assert_email_sent(
        to: user2.email,
        from: {"#{community1.name} - Cambiatus", "no-reply@cambiatus.com"},
        subject: "Community News"
      )

      assert_email_sent(
        to: user3.email,
        from: {"#{community2.name} - Cambiatus", "no-reply@cambiatus.com"},
        subject: "Community News"
      )

      refute_email_sent(%{to: ^user4_email, subject: "Community News"})
    end

    test "emails wont be sent if community does not have news in last 30 days" do
      community = insert(:community, has_news: true)

      insert(:news,
        community: community,
        updated_at: DateTime.utc_now() |> DateTime.add(-3600 * 24 * 31, :second)
      )

      insert(:news,
        community: community,
        updated_at: DateTime.utc_now() |> DateTime.add(-3600 * 24 * 40, :second)
      )

      user = insert(:user)
      insert(:network, user: user, community: community)

      assert :ok == perform_job(MonthlyDigestWorker, %{})

      refute_email_sent()
    end
  end
end