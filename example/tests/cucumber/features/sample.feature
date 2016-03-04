Feature: Map display

  As an anonymous user
  I want to see the map when I navigate to the application
  So that I can analyze it

  # The background will be run for every scenario
  Background:
    Given I am a new user

  # This scenario will run as part of the Meteor dev cycle because it has the @dev tag
  @watch
  Scenario: Check that we see the correct entry page
    When I navigate to "/"
    Then I should see the title "FLIRT"

  @watch
  Scenario: Entering an unmatched search string should give us toast message
    When I navigate to "/"
    And I search for UnmatchedSearchString
    Then I should see the filter loading screen
    Then I should see a toast message

  @watch
  Scenario: Entering an airport code should give us some paths
    When I navigate to "/"
    And I search for JST
    Then I should see the filter loading screen
    Then I should see some map markers
    And I should see paths between them

  @watch
  Scenario: Entering an airport code and date range should give us some paths
    When I navigate to "/"
    And I enter 02/8/16 into the startDate
    And I search for JST
    Then I should see the filter loading screen
    Then I should see some map markers
    And I should see paths between them
