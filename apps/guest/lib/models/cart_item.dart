class CartItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final bool isDrink;
  int qty;

  CartItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.isDrink,
    this.qty = 1,
  });

  double get lineTotal => price * qty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'isDrink': isDrink,
        'qty': qty,
      };
}
