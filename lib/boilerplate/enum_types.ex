defmodule BoilerPlate.EnumTypes do
  import EnumType

  defenum ChecklistStatus do
    value Open, 0
    value Progress, 1
    value Submitted, 2
    value Returned, 3
    value Completed, 4
    value PartiallyCompleted, 7
    default Unknown
  end

  defenum RequestorChecklistStatus do
    value Open, 0
    value Progress, 1
    value Review, 2
    value Returned, 3
    value Completed, 4
    value PartiallyCompleted, 7
    value AutoDeleted, 9
    value ManualDeleted, 10
    default Unknown
  end

  defenum DashboardStatus do
    value Open, 0
    value Progress, 1
    value Submitted, 2
    value Review, 2
    value Returned, 3
    value Completed, 4
    value Missing, 5
    value MissingApproved, 6
    value AutoDeleted, 9
    value ManualDeleted, 10
    default Unknown
  end
end
