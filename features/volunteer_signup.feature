
Feature: Volunteer signup
  As a volunteer
  I want to sign up for an available shift
  So that I can participate in a volunteer activity

  Scenario: Successfully sign up for an available shift
    Given I am logged in as a volunteer
    And there is a shift with an available spot
    When I sign up for the shift
    Then my signup should be confirmed

  Scenario: Join the waitlist when a shift is full
    Given I am logged in as a volunteer
    And there is a shift with an available spot
    And the shift has reached capacity
    When I join the waitlist
    Then my signup should be waitlisted

  Scenario: Promote a waitlisted volunteer after cancellation
    Given I am logged in as a volunteer
    And there is a shift with an available spot
    And the shift has reached capacity
    When I join the waitlist
    And a confirmed volunteer cancels their signup
    Then my signup should be promoted to confirmed

  Scenario: Reject signup for an overlapping shift
    Given I am logged in as a volunteer
    And there is a shift with an available spot
    And I have a confirmed signup for an overlapping shift
    When I sign up for the shift
    Then the overlapping signup should be rejected
