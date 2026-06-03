import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'dart:developer';

class AddressRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  AddressRepo({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Singleton instance for DI and static wrappers
  static final AddressRepo instance = AddressRepo();

  CollectionReference _userAddressesRef() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }
    return _db.collection('users').doc(user.uid).collection('addresses');
  }

  // --- Static Wrappers for Backward Compatibility ---
  static Future<void> addAddress(AddressModel address) =>
      instance.addAddressInstance(address);
  static Future<void> updateAddress(AddressModel address) =>
      instance.updateAddressInstance(address);
  static Future<void> deleteAddress(String addressId) =>
      instance.deleteAddressInstance(addressId);
  static Future<void> setDefaultAddress(String addressId) =>
      instance.setDefaultAddressInstance(addressId);
  static Future<AddressModel?> getDefaultAddress() =>
      instance.getDefaultAddressInstance();
  static Stream<List<AddressModel>> streamAddresses() =>
      instance.streamAddressesInstance();

  // --- Instance Methods ---

  /// Add a new address or pickup location
  Future<void> addAddressInstance(AddressModel address) async {
    try {
      final docRef = _userAddressesRef().doc(); // generate new ID

      final newAddress = AddressModel(
        id: docRef.id,
        type: address.type,
        fullName: address.fullName,
        phone: address.phone,
        city: address.city,
        area: address.area,
        street: address.street,
        building: address.building,
        floor: address.floor,
        notes: address.notes,
        pickupLocationId: address.pickupLocationId,
        pickupLocationName: address.pickupLocationName,
        defaultAddress: address.defaultAddress,
        createdAt: DateTime.now(), // Set current time
        shippingZoneCode: address.shippingZoneCode,
        governorateCode: address.governorateCode,
        governorate: address.governorate,
        cityCode: address.cityCode,
        mapLatitude: address.mapLatitude,
        mapLongitude: address.mapLongitude,
        mapRawAddress: address.mapRawAddress,
        shippingFeeSnapshot: address.shippingFeeSnapshot,
      );

      final batch = _db.batch();

      if (newAddress.defaultAddress) {
        final querySnapshot = await _userAddressesRef()
            .where('defaultAddress', isEqualTo: true)
            .get();
        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'defaultAddress': false});
        }
      }

      batch.set(docRef, newAddress.toMap());
      await batch.commit();

      log('Address added successfully: ${docRef.id}');
    } catch (e) {
      log('Error adding address: $e');
      rethrow;
    }
  }

  /// Update an existing address
  Future<void> updateAddressInstance(AddressModel address) async {
    try {
      final batch = _db.batch();
      final docRef = _userAddressesRef().doc(address.id);

      if (address.defaultAddress) {
        final querySnapshot = await _userAddressesRef()
            .where('defaultAddress', isEqualTo: true)
            .get();
        for (var doc in querySnapshot.docs) {
          if (doc.id != address.id) {
            batch.update(doc.reference, {'defaultAddress': false});
          }
        }
      }

      batch.update(docRef, address.toMap());
      await batch.commit();

      log('Address updated successfully: ${address.id}');
    } catch (e) {
      log('Error updating address: $e');
      rethrow;
    }
  }

  /// Delete an address (legacy, without fallback logic)
  Future<void> deleteAddressInstance(String addressId) async {
    try {
      await _userAddressesRef().doc(addressId).delete();
      log('Address deleted successfully: $addressId');
    } catch (e) {
      log('Error deleting address: $e');
      rethrow;
    }
  }

  /// Delete an address and promote the newest one to default if needed
  Future<void> deleteAddressWithDefaultFallback(String addressId) async {
    try {
      final addressesRef = _userAddressesRef();

      // We must fetch existing addresses first to determine fallback.
      // Firestore transactions don't support collection queries directly.
      final snapshot = await addressesRef.get();
      final addresses = snapshot.docs
          .map((doc) => AddressModel.fromSnapshot(doc))
          .toList();

      final targetIndex = addresses.indexWhere((a) => a.id == addressId);
      if (targetIndex == -1) return; // Already deleted or doesn't exist

      final target = addresses[targetIndex];

      await _db.runTransaction((transaction) async {
        // Delete target
        transaction.delete(addressesRef.doc(addressId));

        // If we deleted the default and there are others left
        if (target.defaultAddress && addresses.length > 1) {
          final remaining = addresses.where((a) => a.id != addressId).toList();

          // Sort for deterministic newest fallback
          remaining.sort((a, b) {
            final dateA = a.createdAt ?? DateTime(2000);
            final dateB = b.createdAt ?? DateTime(2000);
            return dateB.compareTo(dateA); // Newest first
          });

          final newest = remaining.first;
          transaction.update(addressesRef.doc(newest.id), {
            'defaultAddress': true,
          });
          log('Fallback: Promoted ${newest.id} to default.');
        }
      });
    } catch (e) {
      log('Error deleting address with fallback: $e');
      rethrow;
    }
  }

  /// Set an address as default and unset others
  Future<void> setDefaultAddressInstance(String addressId) async {
    try {
      final batch = _db.batch();
      final addressesRef = _userAddressesRef();

      final querySnapshot = await addressesRef.get();
      for (var doc in querySnapshot.docs) {
        if (doc.id == addressId) {
          batch.update(doc.reference, {'defaultAddress': true});
        } else {
          if (doc.data() is Map<String, dynamic> &&
              (doc.data() as Map<String, dynamic>)['defaultAddress'] == true) {
            batch.update(doc.reference, {'defaultAddress': false});
          }
        }
      }

      await batch.commit();
      log('Address $addressId set as default.');
    } catch (e) {
      log('Error setting default address: $e');
      rethrow;
    }
  }

  /// Get the current default address
  Future<AddressModel?> getDefaultAddressInstance() async {
    try {
      final querySnapshot = await _userAddressesRef()
          .where('defaultAddress', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return AddressModel.fromSnapshot(querySnapshot.docs.first);
    } catch (e) {
      log('Error getting default address: $e');
      return null;
    }
  }

  /// Get stream of user addresses
  Stream<List<AddressModel>> streamAddressesInstance() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .snapshots()
        .map((snapshot) {
          final addresses = snapshot.docs
              .map((doc) => AddressModel.fromSnapshot(doc))
              .toList();

          // Sort: defaultAddress == true first, then newest first
          addresses.sort((a, b) {
            if (a.defaultAddress && !b.defaultAddress) return -1;
            if (!a.defaultAddress && b.defaultAddress) return 1;

            final dateA = a.createdAt ?? DateTime(2000);
            final dateB = b.createdAt ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });

          return addresses;
        });
  }
}
