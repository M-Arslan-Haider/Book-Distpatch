// lib/Models/visit_constants.dart
//
// Dropdown option lists — copied 1:1 from the approved reference
// (gps_visits_followups_mobile.html) so behaviour matches exactly.

class VisitConstants {
  VisitConstants._();

  static const List<String> projects = [
    'Green Valley Residencia',
    'City Business District',
    'Royal Enclave',
    'Sialkot Smart City',
    'Canal View Housing',
    'Prime Commercial Center',
  ];

  static const List<String> propTypes = [
    'Residential Plot',
    'Commercial Plot',
    'House',
    'Apartment',
    'Shop',
    'Office',
    'Farmhouse',
    'Other',
  ];

  static const List<String> timelines = [
    'Immediate',
    'Within 1 Month',
    '1–3 Months',
    '3–6 Months',
    'More Than 6 Months',
  ];

  static const List<String> visitTypes = [
    'Office Visit',
    'Site Visit',
    'Customer Location',
    'Online Meeting',
  ];

  static const List<String> interestLevels = ['Hot', 'Warm', 'Cold'];

  static const List<String> responses = [
    'Interested',
    'Considering',
    'Not Interested',
    'Requires More Information',
    'Decision Pending',
  ];

  static const List<String> nextActions = [
    'Follow-up Call',
    'WhatsApp Message',
    'Site Visit',
    'Office Meeting',
    'Send Proposal',
    'Negotiation',
    'Close Lead',
    'No Further Action',
  ];

  static const List<String> statusFilters = [
    'All',
    'Planned',
    'Completed',
    'Cancelled',
    'Missed',
  ];
}

class FollowupConstants {
  FollowupConstants._();

  static const List<String> methods = [
    'Phone Call',
    'WhatsApp',
    'Email',
    'Office Meeting',
    'Site Visit',
    'Online Meeting',
  ];

  static const List<String> results = [
    'Successful',
    'Customer Interested',
    'Customer Needs Time',
    'No Answer',
    'Call Back Requested',
    'Meeting Scheduled',
    'Site Visit Scheduled',
    'Not Interested',
    'Wrong Number',
  ];

  static const List<String> priorities = ['High', 'Medium', 'Low'];

  static const List<String> reminders = [
    'At Time',
    '15 Minutes Before',
    '30 Minutes Before',
    '1 Hour Before',
    '3 Hours Before',
    '1 Day Before',
  ];

  static const List<String> rescheduleReasons = [
    'Customer not available',
    'Employee not available',
    'Customer requested new time',
    'Travel / weather issue',
    'Priority changed',
    'Other',
  ];

  static const List<String> subTabs = [
    'Today',
    'Upcoming',
    'Missed',
    'Rescheduled',
    'Completed',
    'All',
  ];
}