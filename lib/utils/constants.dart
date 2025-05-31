import 'package:flutter/material.dart';

class AppConstants {
  // Categorias
  static const String defaultCategory = 'Adicione as categorias aqui';
  static const Color defaultCategoryColor = Color(0xFF9E9E9E);
  
  // Cores do tema
  static const Color primaryBlue = Colors.blue;
  static const Color primaryTeal = Colors.teal;
  static const Color backgroundBlue = Colors.blue;
  
  // Durações
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration loadingDelay = Duration(milliseconds: 500);
  
  // Textos
  static const String appName = 'ReminderFlutter.ia';
  static const String noRemindersFound = 'Nenhum lembrete encontrado';
  static const String loadingCategories = 'Carregando categorias...';
  static const String defaultErrorMessage = 'Ops! Algo deu errado.';
  
  // Validações
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 500;
  static const int maxCategoryNameLength = 50;
  
  // Database
  static const String remindersDatabaseName = 'reminders.db';
  static const String categoriesDatabaseName = 'categories.db';
  static const int databaseVersion = 1;
  
  // Notificações
  static const String notificationChannelId = 'reminder_notifications';
  static const String notificationChannelName = 'Lembretes';
  static const String notificationChannelDescription = 'Notificações de lembretes';
}

class AppMessages {
  // Success messages
  static const String categoryCreated = 'Categoria criada com sucesso!';
  static const String categoryDeleted = 'Categoria deletada!';
  static const String reminderSaved = 'Lembrete salvo!';
  static const String reminderUpdated = 'Lembrete atualizado!';
  static const String reminderDeleted = 'Lembrete deletado!';
  static const String notificationsEnabled = 'Notificações ativadas';
  static const String notificationsDisabled = 'Notificações desativadas';
  
  // Error messages
  static const String categoryExists = 'Categoria já existe!';
  static const String categoryRequired = 'Você precisa ter pelo menos uma categoria!';
  static const String titleRequired = 'Por favor, digite um título';
  static const String titleTooLong = 'Título muito longo (máximo 100 caracteres)';
  static const String descriptionTooLong = 'Descrição muito longa (máximo 500 caracteres)';
  static const String categoryNameTooLong = 'Nome da categoria muito longo (máximo 50 caracteres)';
  static const String loadCategoriesError = 'Erro ao carregar categorias';
  static const String loadRemindersError = 'Erro ao carregar lembretes';
  static const String saveReminderError = 'Erro ao salvar lembrete';
  static const String deleteReminderError = 'Erro ao deletar lembrete';
  static const String notificationError = 'Erro ao configurar notificação';
  
  // Confirmation messages
  static const String deleteReminderConfirm = 'Tem certeza que deseja deletar este lembrete?';
  static const String deleteCategoryConfirm = 'Tem certeza que deseja deletar esta categoria?';
  static const String keepDefaultCategory = 'Mantenha esta categoria até adicionar outras!';
}

class AppDimensions {
  // Padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 20.0;
  
  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconXLarge = 32.0;
  
  // Font sizes
  static const double fontSmall = 12.0;
  static const double fontMedium = 14.0;
  static const double fontLarge = 16.0;
  static const double fontXLarge = 18.0;
  static const double fontXXLarge = 24.0;
}
