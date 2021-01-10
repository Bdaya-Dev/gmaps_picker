import 'package:flutter/material.dart';

class AutoCompleteSearch extends StatefulWidget {
  @override
  AutoCompleteSearchState createState() => AutoCompleteSearchState();
}

class AutoCompleteSearchState extends State<AutoCompleteSearch> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search for a locality, landmark or city',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(4),
          ),
          prefixIcon: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, size: 24),
          ),
          prefixIconConstraints: BoxConstraints.loose(Size.fromHeight(32)),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }
}
