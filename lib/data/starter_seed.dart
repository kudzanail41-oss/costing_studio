import '../models/costing_project.dart';

/// A blank project for public distribution: no private client prices or assets.
CostingProject starterSeed() => CostingProject(
  id: 'starter-project',
  product: 'New Product',
  client: '',
  description: '',
  quantity: 1,
  sellingPrice: 0.0,
  targetMargin: 30.0,
  costs: [],
);
