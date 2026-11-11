const fs = require('fs');
const path = require('path');

const targetMap = {
  // Models
  'category_model.dart': 'package:salesarmy/features/inventory/data/models/category_model.dart',
  'invoice_model.dart': 'package:salesarmy/features/billing/data/models/invoice_model.dart',
  'ledger_entry_model.dart': 'package:salesarmy/features/collections/data/models/ledger_entry_model.dart',
  'order_model.dart': 'package:salesarmy/features/orders/data/models/order_model.dart',
  'payment_model.dart': 'package:salesarmy/features/collections/data/models/payment_model.dart',
  'product_model.dart': 'package:salesarmy/features/inventory/data/models/product_model.dart',
  'reminder_model.dart': 'package:salesarmy/features/visits/data/models/reminder_model.dart',
  'shop_model.dart': 'package:salesarmy/features/shops/data/models/shop_model.dart',
  'subscription_plan_model.dart': 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart',
  'super_admin_system_model.dart': 'package:salesarmy/features/admin/data/models/super_admin_system_model.dart',
  'tenant_model.dart': 'package:salesarmy/features/admin/data/models/tenant_model.dart',
  'transaction_item_snapshot.dart': 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart',
  'user_model.dart': 'package:salesarmy/features/auth/data/models/user_model.dart',
  'visit_model.dart': 'package:salesarmy/features/visits/data/models/visit_model.dart',

  // Services
  'app_state.dart': 'package:salesarmy/core/services/app_state.dart',
  'mock_data.dart': 'package:salesarmy/core/services/mock_data.dart',
  'auth_service.dart': 'package:salesarmy/features/auth/data/services/auth_service.dart',
  'tenant_service.dart': 'package:salesarmy/features/admin/data/services/tenant_service.dart',
  'gst_engine.dart': 'package:salesarmy/features/billing/data/services/gst_engine.dart',

  // Utils
  'app_theme.dart': 'package:salesarmy/core/theme/app_theme.dart',
  'feature_gate.dart': 'package:salesarmy/core/utils/feature_gate.dart',
  'formatters.dart': 'package:salesarmy/core/utils/formatters.dart',

  // Core & Sync
  'local_data_cache.dart': 'package:salesarmy/core/cache/local_data_cache.dart',
  'api_response.dart': 'package:salesarmy/core/network/api_response.dart',
  'outbox_manager.dart': 'package:salesarmy/core/sync/outbox_manager.dart',
  'mutation_entity.dart': 'package:salesarmy/core/sync/entities/mutation_entity.dart',
  'sync_cursor_entity.dart': 'package:salesarmy/core/sync/entities/sync_cursor_entity.dart',
  'i_sync_repository.dart': 'package:salesarmy/core/sync/repositories/i_sync_repository.dart',
  'sync_deltas_usecase.dart': 'package:salesarmy/core/sync/usecases/sync_deltas_usecase.dart',
  'sync_repository_impl.dart': 'package:salesarmy/core/sync/repositories/sync_repository_impl.dart',
  'main_shell.dart': 'package:salesarmy/core/navigation/main_shell.dart',

  // Domain & Repositories
  'shop_entity.dart': 'package:salesarmy/features/shops/domain/entities/shop_entity.dart',
  'i_shop_repository.dart': 'package:salesarmy/features/shops/domain/repositories/i_shop_repository.dart',
  'shop_repository_impl.dart': 'package:salesarmy/features/shops/data/repositories/shop_repository_impl.dart',
  'order_entity.dart': 'package:salesarmy/features/orders/domain/entities/order_entity.dart',
  'i_order_repository.dart': 'package:salesarmy/features/orders/domain/repositories/i_order_repository.dart',
  'create_order_usecase.dart': 'package:salesarmy/features/orders/domain/usecases/create_order_usecase.dart',
  'get_paginated_orders_usecase.dart': 'package:salesarmy/features/orders/domain/usecases/get_paginated_orders_usecase.dart',
  'order_repository_impl.dart': 'package:salesarmy/features/orders/data/repositories/order_repository_impl.dart',
  'product_entity.dart': 'package:salesarmy/features/inventory/domain/entities/product_entity.dart',
  'i_product_repository.dart': 'package:salesarmy/features/inventory/domain/repositories/i_product_repository.dart',
  'product_repository_impl.dart': 'package:salesarmy/features/inventory/data/repositories/product_repository_impl.dart',

  // Screens & Dialogs
  'login_screen.dart': 'package:salesarmy/features/auth/presentation/screens/login_screen.dart',
  'splash_screen.dart': 'package:salesarmy/features/auth/presentation/screens/splash_screen.dart',
  'super_admin_console.dart': 'package:salesarmy/features/admin/presentation/screens/super_admin_console.dart',
  'super_admin_login_screen.dart': 'package:salesarmy/features/admin/presentation/screens/super_admin_login_screen.dart',
  'admin_modals.dart': 'package:salesarmy/features/admin/presentation/dialogs/admin_modals.dart',
  'admin_dashboard_tab.dart': 'package:salesarmy/features/admin/presentation/tabs/admin_dashboard_tab.dart',
  'admin_features_tab.dart': 'package:salesarmy/features/admin/presentation/tabs/admin_features_tab.dart',
  'admin_plans_tab.dart': 'package:salesarmy/features/admin/presentation/tabs/admin_plans_tab.dart',
  'admin_settings_tab.dart': 'package:salesarmy/features/admin/presentation/tabs/admin_settings_tab.dart',
  'admin_subscribers_tab.dart': 'package:salesarmy/features/admin/presentation/tabs/admin_subscribers_tab.dart',
  'distributor_dashboard.dart': 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart',
  'shops_tab.dart': 'package:salesarmy/features/shops/presentation/screens/shops_tab.dart',
  'shop_detail_screen.dart': 'package:salesarmy/features/shops/presentation/screens/shop_detail_screen.dart',
  'add_shop_dialog.dart': 'package:salesarmy/features/shops/presentation/dialogs/add_shop_dialog.dart',
  'orders_tab.dart': 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart',
  'order_taker_flow.dart': 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart',
  'complete_and_bill_order_modal.dart': 'package:salesarmy/features/orders/presentation/dialogs/complete_and_bill_order_modal.dart',
  'gst_tax_invoice_viewer.dart': 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart',
  'collections_tab.dart': 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart',
  'collect_payment_dialog.dart': 'package:salesarmy/features/collections/presentation/dialogs/collect_payment_dialog.dart',
  'ledger_report_modal.dart': 'package:salesarmy/features/collections/presentation/dialogs/ledger_report_modal.dart',
  'inventory_tab.dart': 'package:salesarmy/features/inventory/presentation/screens/inventory_tab.dart',
  'visits_tab.dart': 'package:salesarmy/features/visits/presentation/screens/visits_tab.dart',
  'distributor_profile_modal.dart': 'package:salesarmy/features/profile/presentation/dialogs/distributor_profile_modal.dart',
  'hardware_settings_modal.dart': 'package:salesarmy/features/settings/presentation/dialogs/hardware_settings_modal.dart',
};

function getAllFiles(dir, fileList = []) {
  if (!fs.existsSync(dir)) return fileList;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getAllFiles(filePath, fileList);
    } else if (file.endsWith('.dart')) {
      fileList.push(filePath);
    }
  }
  return fileList;
}

const libFiles = getAllFiles(path.resolve('apps/mobile/lib'));
const testFiles = getAllFiles(path.resolve('apps/mobile/test'));
const allFiles = [...libFiles, ...testFiles];

let totalReplacements = 0;
let modifiedFiles = 0;

const importRegex = /import\s+['"]([^'"]+)['"](\s+as\s+[a-zA-Z0-9_]+)?;/g;

for (const file of allFiles) {
  let content = fs.readFileSync(file, 'utf8');
  let fileChanged = false;

  const newContent = content.replace(importRegex, (match, importPath, asClause) => {
    // Only target local or package:salesarmy imports
    if (importPath.startsWith('package:flutter') ||
        importPath.startsWith('package:provider') ||
        importPath.startsWith('package:shared_preferences') ||
        importPath.startsWith('package:google_sign_in') ||
        importPath.startsWith('package:cupertino_icons') ||
        importPath.startsWith('package:flutter_test') ||
        importPath.startsWith('dart:')) {
      return match;
    }

    const basename = path.basename(importPath);
    if (targetMap[basename]) {
      totalReplacements++;
      fileChanged = true;
      const asPart = asClause ? asClause : '';
      return `import '${targetMap[basename]}'${asPart};`;
    }

    return match;
  });

  if (fileChanged) {
    fs.writeFileSync(file, newContent, 'utf8');
    modifiedFiles++;
  }
}

console.log(`Successfully updated ${totalReplacements} imports across ${modifiedFiles} files.`);
