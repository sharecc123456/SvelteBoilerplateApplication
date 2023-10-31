alias BoilerPlate.Repo
alias BoilerPlate.PaymentCoupon

defmodule BoilerPlate.Repo.Migrations.CreatePaymentCoupons do
  use Ecto.Migration

  def up do
    create table(:payment_coupons) do
      add :type, :integer
      add :value, :string
      add :name, :string
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    flush()

    Repo.insert!(%PaymentCoupon{
      name: "ycsus2020",
      type: 0,
      value: "50",
      status: 0,
      flags: 0
    })

    Repo.insert!(%PaymentCoupon{
      name: "__internal_testing__",
      type: 2,
      value: "0",
      status: 0,
      flags: 0
    })

    Repo.insert!(%PaymentCoupon{
      name: "chargeme1337",
      type: 1,
      value: "1337",
      status: 0,
      flags: 0
    })

    Repo.insert!(%PaymentCoupon{
      name: "14dayfreetrial",
      type: 1,
      value: "0;14",
      status: 0,
      flags: 0
    })

    Repo.insert!(%PaymentCoupon{
      name: "SomethingTerriblyBad",
      type: 3,
      value: "0;14",
      status: 0,
      flags: 0
    })

    Repo.insert!(%PaymentCoupon{
      name: "14nocc",
      type: 2,
      value: "0;14",
      status: 0,
      flags: 0
    })

  end

  def down do
    drop table(:payment_coupons)
  end

end
