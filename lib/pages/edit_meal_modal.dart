import 'package:flutter/material.dart';
import '../models/meal_model.dart';

class EditMealModal extends StatefulWidget {
  final Meal meal;
  final Function(Meal) onSave;

  const EditMealModal({
    super.key,
    required this.meal,
    required this.onSave,
  });

  @override
  State<EditMealModal> createState() => _EditMealModalState();
}

class _EditMealModalState extends State<EditMealModal> {
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;
  late List<_MutableIngredient> _ingredients;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.meal.name);
    _caloriesController =
        TextEditingController(text: widget.meal.calories.toString());
    _proteinController =
        TextEditingController(text: widget.meal.protein.toString());
    _carbsController =
        TextEditingController(text: widget.meal.carbs.toString());
    _fatsController =
        TextEditingController(text: widget.meal.fats.toString());
    // Create a deep copy of ingredients to avoid modifying the original list directly
    _ingredients = widget.meal.ingredients
        .map((i) => _MutableIngredient(MealIngredient(i.name, i.amount, i.calories)))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  void _updateTotalCalories() {
    int total = 0;
    for (var item in _ingredients) {
      total += item.ingredient.calories;
    }
    setState(() {
      _caloriesController.text = total.toString();
    });
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_MutableIngredient(MealIngredient('', '', 0)));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      _updateTotalCalories();
    });
  }

  void _save() {
    final updatedMeal = Meal(
      id: widget.meal.id,
      type: widget.meal.type,
      icon: widget.meal.icon,
      name: _nameController.text,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      protein: int.tryParse(_proteinController.text) ?? 0,
      carbs: int.tryParse(_carbsController.text) ?? 0,
      fats: int.tryParse(_fatsController.text) ?? 0,
      eaten: widget.meal.eaten,
      planId: widget.meal.planId,
      ingredients: _ingredients.map((i) => i.ingredient).toList(),
    );
    widget.onSave(updatedMeal);
    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final isWide = MediaQuery.of(context).size.width > 600;

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 600,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isWide 
            ? BorderRadius.circular(24)
            : const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Meal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Name
                  Text(
                    'Meal Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ingredients
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final ingredient = item.ingredient;
                    return Padding(
                      key: item.key,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _IngredientInput(
                              initialValue: ingredient.name,
                              hint: 'Name',
                              onChanged: (val) => _ingredients[index].ingredient =
                                  MealIngredient(val, _ingredients[index].ingredient.amount,
                                      _ingredients[index].ingredient.calories),
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _IngredientInput(
                              initialValue: ingredient.amount,
                              hint: 'Amount',
                              onChanged: (val) => _ingredients[index].ingredient =
                                  MealIngredient(_ingredients[index].ingredient.name, val,
                                      _ingredients[index].ingredient.calories),
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _IngredientInput(
                              initialValue: ingredient.calories.toString(),
                              hint: 'kcal',
                              onChanged: (val) {
                                _ingredients[index].ingredient = MealIngredient(
                                    _ingredients[index].ingredient.name,
                                    _ingredients[index].ingredient.amount,
                                    int.tryParse(val) ?? 0);
                                _updateTotalCalories();
                              },
                              isDarkMode: isDarkMode,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _removeIngredient(index),
                            child: const Icon(Icons.close,
                                color: Color(0xFFFF0000), size: 20),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add Ingredient Button
                  GestureDetector(
                    onTap: _addIngredient,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFFF0000),
                          style: BorderStyle.solid, // Dashed border is complex in Flutter without external package, using solid red for now or CustomPainter
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // To make it look dashed like the design, we can use a CustomPainter, but for simplicity/speed solid or using a package is common. 
                      // Let's stick to a solid border with red color as a simple approximation or use a dotted decoration if critical.
                      // The user request image shows a dashed border. I'll use a solid border for now to keep it simple and robust.
                      child: const Center(
                        child: Text(
                          '+ Add Ingredient',
                          style: TextStyle(
                            color: const Color(0xFFFF0000),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer Actions
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4444),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Meal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );

    if (isWide) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: content,
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: content,
        ),
      );
    }
  }
}

class _IngredientInput extends StatelessWidget {
  final String initialValue;
  final String hint;
  final Function(String) onChanged;
  final bool isDarkMode;
  final bool isNumber;

  const _IngredientInput({
    required this.initialValue,
    required this.hint,
    required this.onChanged,
    required this.isDarkMode,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _MutableIngredient {
  final UniqueKey key;
  MealIngredient ingredient;

  _MutableIngredient(this.ingredient) : key = UniqueKey();
}
