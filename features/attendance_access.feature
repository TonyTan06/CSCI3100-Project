
Feature: Organization isolation for attendance
  As an organizer
  I want attendance records to be restricted to my organization
  So that I cannot access another organization's volunteer records

  Scenario: Organizer cannot view another organization's attendance
    Given I am logged in as an organizer of one organization
    And another organization has a shift with confirmed volunteers
    When I visit the other organization's attendance page
    Then the attendance request should return 404

  Scenario: Organizer can view their own organization's attendance
    Given I am logged in as an organizer of one organization
    And my organization has a shift with confirmed volunteers
    When I visit my organization's attendance page
    Then the attendance request should return 200

  Scenario: Volunteer cannot access attendance management
    Given I am logged in as a volunteer
    And there is a shift with an available spot
    When I visit the attendance page for the shift
    Then the attendance request should return 403
