import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Helper function to create drawer items
    Widget _buildDrawerItem({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
      );
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Navigation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.home,
            title: 'Home',
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacementNamed(context, '/'); // Navigate to Home
            },
          ),
          _buildDrawerItem(
            icon: Icons.person,
            title: 'Profile',
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/profile'); // Navigate to Profile
            },
          ),
          _buildDrawerItem(
            icon: Icons.search,
            title: 'Search',
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/search'); // Navigate to Search
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/settings'); // Navigate to Settings
            },
          ),
        ],
      ),
    );
  }
}
