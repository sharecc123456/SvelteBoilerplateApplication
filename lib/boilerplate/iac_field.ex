import Bitwise

defmodule BoilerPlate.IACField do
  use Ecto.Schema
  import Ecto.Changeset

  schema "iac_field" do
    field :parent_id, :integer
    field :parent_type, :integer
    field :name, :string
    field :location_type, :integer
    field :location_value_1, :float
    field :location_value_2, :float
    field :location_value_3, :float
    field :location_value_4, :float
    field :location_value_5, :float
    field :location_value_6, :float
    field :field_type, :integer
    field :master_field_id, :integer
    field :set_value, :string
    field :default_value, :string
    # Internal value map
    # 1
    #   radiobox -> selection_group
    field :internal_value_1, :string
    # 0 -> anyone
    # 1 -> requestor BEFORE
    # 2 -> requestor AFTER
    # 3 -> recipient
    field :fill_type, :integer, default: 3
    field :status, :integer

    # bit 0 -> :deleted
    # bit 1 -> :immutable_by_recipient
    # bit 5 -> :created_by_recipient
    field :flags, :integer
    field :label, :string, default: ""
    field :label_value, :string, default: nil
    field :label_question, :string, default: nil
    field :label_question_type, :string, default: nil
    field :label_id, :id
    field :repeat_entry_form_id, :id
    field :allow_multiline, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(iacfd, attrs) do
    iacfd
    |> cast(attrs, [
      :parent_id,
      :parent_type,
      :location_type,
      :location_value_1,
      :location_value_2,
      :location_value_3,
      :location_value_4,
      :location_value_5,
      :location_value_6,
      :field_type,
      :master_field_id,
      :set_value,
      :default_value,
      :internal_value_1,
      :fill_type,
      :status,
      :flags,
      :name,
      :label,
      :label_value,
      :label_question,
      :label_question_type,
      :label_id,
      :repeat_entry_form_id,
      :allow_multiline
    ])
    |> validate_required([
      :parent_id,
      :parent_type,
      :field_type,
      :master_field_id,
      :status,
      :flags
    ])
  end

  def flags(stuff) do
    stuff
    |> Enum.reduce(0, fn e, a ->
      case e do
        :delete -> a ||| 1
        :immutable_by_recipient -> a ||| 2
        _ -> a
      end
    end)
  end

  def displayable_field?(field) do
    if field.location_type == 1 do
      field.location_value_3 != 0 and field.location_value_4 != 0
    else
      true
    end
  end

  def parent_type_to_atom(parent_type) do
    case parent_type do
      1 -> :master_form
      2 -> :assigned_form
      _ -> :unknown
    end
  end

  def atom_to_parent_type(atom) do
    case atom do
      :master_form -> 1
      :assigned_form -> 2
      _ -> 0
    end
  end

  def location_type_to_atom(parent_type) do
    case parent_type do
      1 -> :textract_topleft
      2 -> :not_written
      _ -> :unknown
    end
  end

  def atom_to_location_type(atom) do
    case atom do
      :textract_topleft -> 1
      :not_written -> 2
      _ -> 0
    end
  end

  def type_string_to_type_int(field_type) do
    case field_type do
      "text" -> 1
      "selection" -> 2
      "signature" -> 3
      # "line" -> 4
      # "horizontal_line" -> 5
      "table" -> 4
      # TODO: should raise?
      _ -> 0
    end
  end

  def is_label_value_supported?(i) do
    case i do
      1 -> true
      _ -> false
    end
  end

  def field_type_to_int(field_type) do
    case field_type do
      :text -> 1
      :selection -> 2
      :signature -> 3
      :table -> 4
      # :line -> 4
      # :horizontal_line -> 5
      # TODO: should raise?
      _ -> 0
    end
  end

  def int_to_field_type(i) do
    case i do
      1 -> :text
      2 -> :selection
      3 -> :signature
      4 -> :table
      # 4 -> :line
      # 5 -> :horizontal_line
      # TODO: should raise?
      _ -> :unknown
    end
  end

  def make_location_spec(f) do
    lv1 = f.location_value_1
    lv2 = f.location_value_2
    lv3 = f.location_value_3
    lv4 = f.location_value_4
    page_no = f.location_value_6
    lv5 = f.id
    lv6 = f.field_type
    bX = min(lv2, lv2 + lv3)
    fX = max(lv2, lv2 + lv3)
    bY = min(lv1, lv1 + lv4)
    fY = max(lv1, lv1 + lv4)

    [bX, fX, bY, fY, lv5, lv6, page_no]
  end

  def compare_location_specs(fA, sA) do
    fY = floor(Enum.at(fA, 2) * 100)
    sY = floor(Enum.at(sA, 2) * 100)
    fX = floor(Enum.at(fA, 0) * 100)
    sX = floor(Enum.at(sA, 0) * 100)

    cond do
      Enum.at(fA, 6) < Enum.at(sA, 6) -> :lt
      Enum.at(fA, 6) > Enum.at(sA, 6) -> :gt
      fY < sY -> :lt
      fY > sY -> :gt
      fX < sX -> :lt
      fX > sX -> :gt
      fX == sX -> :eq
    end
  end

  def compare(f, s) do
    fA = make_location_spec(f)
    sA = make_location_spec(s)

    compare_location_specs(fA, sA)
  end

  def text_to_fill_type(fill_type_txt) do
    case fill_type_txt do
      "requestor" -> 1
      "recipient" -> 2
      "review" -> 3
      _ -> 0
    end
  end

  def default_question_type_for_field(field) do
    case field do
      2 -> "checkbox"
      _ -> "shortAnswer"
    end
  end
end
