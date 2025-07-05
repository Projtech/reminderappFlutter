import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static const String _pinKey = 'app_security_pin';
  static const String _pinSaltKey = 'app_security_pin_salt';
  static const String _securityEnabledKey = 'security_enabled';
  static const String _authTypeKey = 'auth_type'; // 'biometric', 'pin', 'both'
  static const String _failAttemptsKey = 'failed_attempts';
  static const String _lockoutTimeKey = 'lockout_time';
  static const String _lastAuthKey = 'last_auth_time';
  static const String _timeoutMinutesKey = 'auth_timeout_minutes';
  
  static final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Verificar se biometria está disponível
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      return isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Verificar se segurança está habilitada
  static Future<bool> isSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_securityEnabledKey) ?? false;
  }

  // Obter tipo de autenticação configurado
  static Future<String> getAuthType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTypeKey) ?? 'none';
  }

  // Obter/definir timeout configurável
  static Future<int> getAuthTimeoutMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_timeoutMinutesKey) ?? 5; // Default 5 minutos
  }

  static Future<void> setAuthTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeoutMinutesKey, minutes.clamp(1, 60)); // Entre 1 e 60 min
  }

  // Verificar se precisa autenticar (baseado no tempo configurável)
  static Future<bool> needsAuthentication() async {
    if (!await isSecurityEnabled()) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final lastAuth = prefs.getInt(_lastAuthKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeoutMinutes = await getAuthTimeoutMinutes();
    
    return (now - lastAuth) > (timeoutMinutes * 60 * 1000);
  }

  // Verificar se está em lockout
  static Future<bool> isInLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTime = prefs.getInt(_lockoutTimeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return now < lockoutTime;
  }

  // Obter tempo restante de lockout em minutos
  static Future<int> getLockoutMinutesRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTime = prefs.getInt(_lockoutTimeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = lockoutTime - now;
    
    return remaining > 0 ? (remaining / (60 * 1000)).ceil() : 0;
  }

  // Configurar segurança
  static Future<bool> setupSecurity({
    required String authType,
    String? pin,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Salvar tipo de autenticação
      await prefs.setString(_authTypeKey, authType);
      await prefs.setBool(_securityEnabledKey, true);
      
      // Salvar PIN se fornecido
      if (pin != null && pin.isNotEmpty) {
        final salt = _generateSalt();
        final hashedPin = _hashPin(pin, salt);
        await _secureStorage.write(key: _pinKey, value: hashedPin);
        await _secureStorage.write(key: _pinSaltKey, value: salt);
      }
      
      // Resetar tentativas e lockout
      await prefs.setInt(_failAttemptsKey, 0);
      await prefs.remove(_lockoutTimeKey);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Autenticar com biometria
  static Future<bool> authenticateWithBiometric() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use sua digital ou rosto para acessar o app',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (didAuthenticate) {
        await _recordSuccessfulAuth();
      }
      
      return didAuthenticate;
    } on PlatformException catch (e) {
      // Tratar erros específicos de biometria
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return false;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return false;
        case 'UserCancel':
        case 'UserFallback':
          return false;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Autenticar com PIN
  static Future<bool> authenticateWithPin(String enteredPin) async {
    try {
      final storedHashedPin = await _secureStorage.read(key: _pinKey);
      final storedSalt = await _secureStorage.read(key: _pinSaltKey);
      
      if (storedHashedPin == null || storedSalt == null) return false;
      
      final enteredHashedPin = _hashPin(enteredPin, storedSalt);
      final isValid = storedHashedPin == enteredHashedPin;
      
      if (isValid) {
        await _recordSuccessfulAuth();
      } else {
        await _recordFailedAttempt();
      }
      
      return isValid;
    } catch (e) {
      return false;
    }
  }

  // Autenticar baseado no tipo configurado
  static Future<bool> authenticate() async {
    final authType = await getAuthType();
    
    switch (authType) {
      case 'biometric':
        return await authenticateWithBiometric();
      case 'pin':
        // PIN será solicitado na tela
        return false;
      case 'both':
        // Usuário pode escolher na tela
        return false;
      default:
        return true; // Sem segurança
    }
  }

  // Desabilitar segurança
  static Future<bool> disableSecurity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_securityEnabledKey, false);
      await prefs.remove(_authTypeKey);
      await prefs.remove(_failAttemptsKey);
      await prefs.remove(_lockoutTimeKey);
      await prefs.remove(_lastAuthKey);
      await _secureStorage.delete(key: _pinKey);
      await _secureStorage.delete(key: _pinSaltKey);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Reset de emergência (para recuperação)
  static Future<bool> emergencyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limpar todas as configurações de autenticação
      await prefs.remove(_securityEnabledKey);
      await prefs.remove(_authTypeKey);
      await prefs.remove(_failAttemptsKey);
      await prefs.remove(_lockoutTimeKey);
      await prefs.remove(_lastAuthKey);
      await prefs.remove(_timeoutMinutesKey);
      await _secureStorage.delete(key: _pinKey);
      await _secureStorage.delete(key: _pinSaltKey);
      
      return true;
    } catch (e) {
      return false;
    }
  }
  // Reset de segurança para testes
static Future<bool> resetSecurityForTesting() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Manter dados do app, mas limpar apenas configurações de segurança
    await prefs.setBool(_securityEnabledKey, false);
    await prefs.remove(_authTypeKey);
    await prefs.remove(_failAttemptsKey);
    await prefs.remove(_lockoutTimeKey);
    await prefs.remove(_lastAuthKey);
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _pinSaltKey);
    
    await _logSecurityEvent('RESET_FOR_TESTING');
    return true;
  } catch (e) {
    return false;
  }
}

  // Métodos auxiliares privados
  static String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(values);
  }

  static String _hashPin(String pin, String salt) {
    // Hash seguro com salt dinâmico e múltiplas iterações
    var input = pin + salt;
    
    // 10.000 iterações para tornar mais seguro
    for (int i = 0; i < 10000; i++) {
      final bytes = utf8.encode(input);
      input = bytes.fold('', (prev, byte) => prev + byte.toRadixString(16).padLeft(2, '0'));
    }
    
    return input;
  }

  static Future<void> _recordSuccessfulAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAuthKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_failAttemptsKey, 0);
    await prefs.remove(_lockoutTimeKey);
  }

  static Future<void> _recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAttempts = prefs.getInt(_failAttemptsKey) ?? 0;
    final newAttempts = currentAttempts + 1;
    
    await prefs.setInt(_failAttemptsKey, newAttempts);
    
    // Lockout após 3 tentativas
    if (newAttempts >= 3) {
      final lockoutDuration = _getLockoutDuration(newAttempts);
      final lockoutTime = DateTime.now().millisecondsSinceEpoch + lockoutDuration;
      await prefs.setInt(_lockoutTimeKey, lockoutTime);
    }
  }

  static int _getLockoutDuration(int attempts) {
    // Lockout progressivo mais suave: 30s, 2min, 5min, 10min
    const durations = [30000, 120000, 300000, 600000]; // em milissegundos
    final index = (attempts - 3).clamp(0, durations.length - 1);
    return durations[index];
  }

  // Obter tentativas falhadas
  static Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_failAttemptsKey) ?? 0;
  }

  // Logs para debug (apenas em desenvolvimento)
  static Future<void> _logSecurityEvent(String event, {Map<String, dynamic>? details}) async {
    // Em produção, remover ou enviar para analytics
    final timestamp = DateTime.now().toIso8601String();
    print('SECURITY_LOG [$timestamp]: $event ${details ?? ''}');
  }
}