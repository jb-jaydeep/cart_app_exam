import 'dart:convert';

List<Product> productFromJson(String str) =>
    List<Product>.from(json.decode(str).map((e) => Product.fromJson(e)));

String productToJson(List<Product> data) =>
    json.encode(List<dynamic>.from(data.map((e) => e.toJson())));

class Product {
  Product({
    this.id,
    this.name,
    this.image,
    this.quantity,
  });

  int? id;
  String? name;
  String? image;
  int? quantity;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json["id"] ?? 0,
    name: json["name"] ?? "",
    image: json["image"] ?? "",
    quantity: json["quantity"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "image": image,
    "quantity": quantity,
  };
}