import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../widgets/delivery_address_dialog.dart';

class AddressBookScreen extends StatelessWidget {
  const AddressBookScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sổ địa chỉ')),
      body: location.addresses.isEmpty
          ? const Center(child: Text('Chưa có địa chỉ giao hàng'))
          : ListView.builder(
              itemCount: location.addresses.length,
              itemBuilder: (context, index) {
                final address = location.addresses[index];
                final isDefault = location.defaultAddress?.id == address.id;
                return ListTile(
                  title: Text(address.fullAddress),
                  subtitle: Text(
                    isDefault ? 'Mặc định' : 'Chạm để đặt làm mặc định',
                  ),
                  onTap: () => location.setDefault(address.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => DeliveryAddressDialog.show(
                          context,
                          address: address,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => location.deleteAddress(address.id),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => DeliveryAddressDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
