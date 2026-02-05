@{
  # Severity levels to include
  Severity = @('Error', 'Warning')

  # Rules to exclude
  ExcludeRules = @(
    'PSUseApprovedVerbs',
    'PSUseShouldProcessForStateChangingFunctions'
  )
}
