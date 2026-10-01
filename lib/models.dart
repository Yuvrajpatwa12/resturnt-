class Product {
  final String title;
  final String price;
  final String image;
  final String tag;
  final String rating;
  final String discount;
  final String? description;
  final String? slogan; // Added
  final String? modelUrl;
  final String? iosModelUrl;
  final bool hasVariants;
  final String? variantType;
  final List<Map<String, String>> variants;
  final String? prepTime;
  final bool isAvailable;
  final bool isComingSoon;

  Product({
    required this.title,
    required this.price,
    required this.image,
    required this.tag,
    required this.rating,
    this.discount = '',
    this.description,
    this.slogan,
    this.modelUrl,
    this.iosModelUrl,
    this.hasVariants = false,
    this.variantType,
    this.variants = const [],
    this.prepTime,
    this.isAvailable = true,
    this.isComingSoon = false,
  });
}

class UnavailableDay {
  final String id;
  final String title;
  final String reasonType;
  final DateTime startDate;
  final DateTime endDate;
  final String availabilityType;
  final String? startTime;
  final String? endTime;
  final String repeatType;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  UnavailableDay({
    required this.id,
    required this.title,
    required this.reasonType,
    required this.startDate,
    required this.endDate,
    required this.availabilityType,
    this.startTime,
    this.endTime,
    required this.repeatType,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  factory UnavailableDay.fromMap(Map<String, dynamic> map) {
    return UnavailableDay(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      reasonType: map['reason_type'] ?? 'Other',
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      availabilityType: map['availability_type'] ?? 'Full Day',
      startTime: map['start_time'],
      endTime: map['end_time'],
      repeatType: map['repeat_type'] ?? 'Does Not Repeat',
      notes: map['notes'],
      isActive: map['status'] == 'Active' || map['isActive'] == true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'reason_type': reasonType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'availability_type': availabilityType,
      'start_time': startTime,
      'end_time': endTime,
      'repeat_type': repeatType,
      'notes': notes,
      'status': isActive ? 'Active' : 'Disabled',
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum OccupancyStatus { Vacant, Occupied, Reserved, DueCheckIn, DueCheckOut }

enum RoomCondition { Clean, Dirty, Cleaning, Inspected, Maintenance, OutOfOrder, OutOfService }

enum HousekeepingStatus { CleaningQueue, Assigned, InProgress, Completed, InspectionPending }

class HotelRoom {
  final String id;
  final String roomNumber;
  final String type;
  final int floor;
  final int capacity;
  final double price;
  final List<String> amenities;
  final OccupancyStatus occupancy;
  final RoomCondition condition;
  final HousekeepingStatus housekeeping;
  final String? currentGuest;
  final String? bookingId;
  final String? lastCleaned;
  final String? maintenanceHistory;

  HotelRoom({
    required this.id,
    required this.roomNumber,
    required this.type,
    required this.floor,
    required this.capacity,
    required this.price,
    required this.amenities,
    required this.occupancy,
    required this.condition,
    required this.housekeeping,
    this.currentGuest,
    this.bookingId,
    this.lastCleaned,
    this.maintenanceHistory,
  });
}

enum MaintenancePriority { Low, Medium, High, Urgent }

enum MaintenanceStatus { Reported, Assigned, InProgress, OnHold, Resolved }

class MaintenanceRequest {
  final String id;
  final String roomNumber;
  final String category;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final String description;
  final String reportedBy;
  final DateTime reportedAt;
  final String? technician;
  final double? cost;

  MaintenanceRequest({
    required this.id,
    required this.roomNumber,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
    required this.reportedBy,
    required this.reportedAt,
    this.technician,
    this.cost,
  });
}

class LostAndFoundItem {
  final String id;
  final String itemName;
  final String roomNumber;
  final String foundBy;
  final DateTime foundDate;
  final String status; // Claimed, Unclaimed
  final String? storageLocation;

  LostAndFoundItem({
    required this.id,
    required this.itemName,
    required this.roomNumber,
    required this.foundBy,
    required this.foundDate,
    required this.status,
    this.storageLocation,
  });
}

enum BookingStatus { Pending, Staying, Completed, Cancelled, Cleaning }

class Booking {
  final String id;
  String guestName;
  DateTime? dob;
  int guestCount;
  String address;
  String phoneNumber;
  List<String> roomNumbers;
  String roomType;
  double roomRate;
  DateTime scheduledCheckIn;
  DateTime scheduledCheckOut;
  DateTime? actualCheckIn;
  DateTime? actualCheckOut;
  BookingStatus status;
  HousekeepingStatus housekeepingStatus;
  bool isPaid;
  bool isIdVerified;
  List<OrderItem> orders;
  String? staffNotes;
  String? cleanedBy;

  Booking({
    required this.id,
    required this.guestName,
    this.dob,
    required this.guestCount,
    required this.address,
    required this.phoneNumber,
    required this.roomNumbers,
    required this.roomType,
    this.roomRate = 8500.0,
    required this.scheduledCheckIn,
    required this.scheduledCheckOut,
    this.actualCheckIn,
    this.actualCheckOut,
    this.status = BookingStatus.Pending,
    this.housekeepingStatus = HousekeepingStatus.Completed,
    this.isPaid = false,
    this.isIdVerified = false,
    this.orders = const [],
    this.staffNotes,
    this.cleanedBy,
  });

  double get totalRoomCharges {
    int nights = scheduledCheckOut.difference(scheduledCheckIn).inDays;
    if (nights <= 0) nights = 1;
    return nights * roomRate;
  }

  double get totalOrderCharges {
    double total = 0;
    for (var order in orders) {
      double price = double.tryParse(order.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      int qty = int.tryParse(order.qty) ?? 1;
      total += price * qty;
    }
    return total;
  }

  double get grandTotal => (totalRoomCharges + totalOrderCharges) * 1.13; // Including 13% Tax
}

class OrderItem {
  final String name;
  final String qty;
  final String price;

  OrderItem({required this.name, required this.qty, required this.price});
}
