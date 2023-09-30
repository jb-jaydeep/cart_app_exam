import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import '../model/product_model.dart';

class DBHelper {
  DBHelper._();

  static final DBHelper dbHelper = DBHelper._();

  static Database? db;
  String tableName = "product";
  String id = "id";
  String name = "name";
  String image = "image";
  String qty = "quantity";
  List<Product> finalProductList = [];
  List<Product> productList = [];
  List<String> images = [];
  Random random = Random();
  int randomNumber = 0;
  int countDown = 30;
  bool isAddToCart = false;
  bool isProductInStock = true;
  Timer? outOfStockTimer;
  bool isOutOfStock = false;

  Future initDB() async {
    String dbLocation = await getDatabasesPath();

    String path = join(dbLocation, "products.db");

    db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        String query =
            "CREATE TABLE IF NOT EXISTS products(id TEXT PRIMARY KEY, name TEXT NOT NULL, price NUMERIC NOT NULL, quantity INTEGER NOT NULL);";

        String query1 =
            "CREATE TABLE IF NOT EXISTS cart(id TEXT, name TEXT NOT NULL, price NUMERIC NOT NULL, quantity INTEGER NOT NULL);";

        await db.execute(query);
        await db.execute(query1);
      },
    );
  }

  Future<Database?> init() async {
    String path = await getDatabasesPath();

    String dataBasePath = join(path, "product.db");

    db = await openDatabase(
      dataBasePath,
      version: 1,
      onCreate: (Database database, version) async {
        String query =
            "CREATE TABLE IF NOT EXISTS $tableName($id INTEGER PRIMARY KEY AUTOINCREMENT, $name TEXT, $image TEXT, $qty INTEGER);";
        await database.execute(query);
      },
    );
    String query =
        "CREATE TABLE IF NOT EXISTS $tableName($id INTEGER PRIMARY KEY AUTOINCREMENT, $name TEXT, $image TEXT, $qty INTEGER);";
    db!.execute(query);
    return db;
  }


  Future insertBulkRecord() async {
    deleteTable();
    await init();

    for (Product product in finalProductList) {
      String image = await getImagesBytes(url: product.image ?? "") ?? "";
      images.add(image);
    }

    for (var i = 0; i < finalProductList.length; i++) {
      Product product = finalProductList[i];
      String sql =
          "INSERT INTO $tableName VALUES(null,'${product
          .name}', '${images[i]}', ${product.quantity})";
      await db!.rawInsert(sql);
    }
  }

  Future<String?> getImagesBytes({required String url}) async {
    http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Uint8List bytes = response.bodyBytes;
      return base64Encode(bytes);
    }
    return null;
  }

  Future deleteTable() async {
    await init();
    String sql = "DROP TABLE $tableName";
    await db!.execute(sql);
  }

  Future<void> fetchData() async {
    String sql = "SELECT * FROM $tableName";

    List<Map<String, dynamic>> data = await db!.rawQuery(sql);
    productList.clear();
    productList.addAll(productFromJson(jsonEncode(data)));
    randomNumber = random.nextInt(15);
    countDownTimer();
  }

  Future<void> recoverData() async {
    String sql = "SELECT * FROM $tableName";

    List<Map<String, dynamic>> data = await db!.rawQuery(sql);
    productList.clear();
    productList.addAll(productFromJson(jsonEncode(data)));
  }

  Future<void> addToCart({required Product product}) async {
    await init();

    int? quantity;
    if (product.quantity! > 0) {
      quantity = product.quantity! - 1;
    }

    String query =
        "UPDATE  $tableName SET $qty = ${quantity ?? 0} WHERE $id = ${product
        .id};";
    db!.rawUpdate(query);

    String selectQuery = "SELECT *FROM $tableName WHERE $id = ${product.id};";
    List<Map<String, dynamic>> data = await db!.rawQuery(selectQuery);
    productList[product.id! - 1] = Product.fromJson(data[0]);
  }


  Future<void> loadString({required String path}) async {
    String productData = await rootBundle.loadString(path);
    final productList = productFromJson(productData);
    finalProductList.clear();
    finalProductList.addAll(productList);
  }


  void countDownTimer() async {
    await Future.delayed(const Duration(seconds: 1));
    countDown--;

    if (countDown == 20 && !isAddToCart) {
      isProductInStock = false;
    }

    if (countDown == 0) {
      if (!isProductInStock) {
        isProductInStock = true;
        resetQuantity(); // Reset quantity after 10 seconds if out of stock.
      }
      await fetchData();
      countDown = isProductInStock ? 10 : 30;
      isAddToCart = false;
    } else {
      countDownTimer();
    }
  }

  Future<void> markProductOutOfStock() async {
    if (finalProductList.isNotEmpty) {
      int randomIndex = random.nextInt(finalProductList.length);
      int id = finalProductList[randomIndex].id!;

      String query = "UPDATE  $tableName SET $qty = 0 WHERE $id = $id;";
      await db!.rawUpdate(query);

      String selectQuery = "SELECT * FROM $tableName WHERE $id = $id;";
      List<Map<String, dynamic>> data = await db!.rawQuery(selectQuery);
      finalProductList[randomIndex] = Product.fromJson(data[0]);
      isOutOfStock = true;
    }
  }

  Future<void> updateProductQuantity(Product product) async {
    String query = "UPDATE $tableName SET $qty = 0 WHERE $id = ${product.id};";
    await db!.rawUpdate(query);
  }

  Future<void> resetQuantity() async {
    for (Product product in dbHelper.productList) {
      if (product.quantity! > 0) {
        product.quantity = 50;
        await updateProductQuantity(product);
      }
    }
  }


  // Future<void> stockManage() async {
  //   db = await init();
  //   int randomIndex = dbHelper.randomNumber;
  //   int id = finalProductList[randomNumber].id!;
  //
  //   String query = "UPDATE  $tableName SET $qty = 0 WHERE $id = $id;";
  //   await db!.rawUpdate(query);
  //
  //   String selectQuery = "SELECT * FROM $tableName WHERE $id = $id;";
  //   List<Map<String, dynamic>> data = await db!.rawQuery(selectQuery);
  //   finalProductList[randomNumber] = Product.fromJson(data[0]);
  //
  //   if (randomIndex >= 0 && randomIndex < dbHelper.productList.length) {
  //     Product selectedProduct = dbHelper.productList[randomIndex];
  //     if (selectedProduct.quantity! > 0) {
  //       selectedProduct.quantity = 0;
  //       await updateProductQuantity(selectedProduct);
  //     }
  //   }
  // }
  Future<void> stockManage() async {
    db = await init();
    int randomIndex = dbHelper.randomNumber; // Get the current random index
    int id = finalProductList[randomIndex].id!;

    String query = "UPDATE $tableName SET $qty = 0 WHERE $id = $id;";
    await db!.rawUpdate(query);

    String selectQuery = "SELECT * FROM $tableName WHERE $id = $id;";
    List<Map<String, dynamic>> data = await db!.rawQuery(selectQuery);
    finalProductList[randomIndex] = Product.fromJson(data[0]);

    if (dbHelper.countDown == 20) {
      dbHelper.randomNumber = random.nextInt(finalProductList.length);
    }
  }
}