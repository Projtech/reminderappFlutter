import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class AuthService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static const String _pinKey = 'app_security_pin';
  static const String _pinSaltKey = 'app_security_pin_salt';
  static const String _securityEnabledKey = 'security_enabled';
  static const String _authTypeKey = 'auth_type'; // 'pin'
  static const String _failAttemptsKey = 'failed_attempts';
  static const String _lockoutTimeKey = 'lockout_time';
  static const String _lastAuthKey = 'last_auth_time';
  static const String _timeoutMinutesKey = 'auth_timeout_minutes';

  // Verificar se segurança está habilitada
  static Future<bool> isSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_securityEnabledKey) ?? false;
    if (!isEnabled) return false;

    // Verificar se o PIN está realmente armazenado
    final authType = prefs.getString(_authTypeKey) ?? 'none';
    if (authType == 'pin') {
      final storedPin = await _secureStorage.read(key: _pinKey);
      return storedPin != null;
    }
    return isEnabled;
  }

  // Obter tipo de autenticação configurado
  static Future<String> getAuthType() async {
    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_authTypeKey) ?? 'none';

    // Verificar se o PIN está realmente armazenado
    if (authType == 'pin') {
      final storedPin = await _secureStorage.read(key: _pinKey);
      if (storedPin == null) {
        await prefs.setString(_authTypeKey, 'none');
        await prefs.setBool(_securityEnabledKey, false);
        return 'none';
      }
    }
    return authType;
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
      
      // Verificar se PIN foi fornecido
      if (authType == 'pin' && (pin == null || pin.isEmpty)) {
        await disableSecurity();
        return false;
      }
      
      // Salvar tipo de autenticação
      await prefs.setString(_authTypeKey, authType);
      await prefs.setBool(_securityEnabledKey, true);
      
      // Salvar PIN
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
      case 'pin':
        // PIN será solicitado na tela
        return false; // Retorna false para que a tela de PIN seja exibida
      default:
        return true; // Sem segurança
    }
  }

  // Verificar se tem PIN configurado
  static Future<bool> hasPinConfigured() async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    return storedPin != null;
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
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Novo método para resetar apenas o PIN
  static Future<bool> resetPinOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remover apenas o PIN e o salt
      await _secureStorage.delete(key: _pinKey);
      await _secureStorage.delete(key: _pinSaltKey);
      
      // Desabilitar segurança
      await prefs.setString(_authTypeKey, 'none');
      await prefs.setBool(_securityEnabledKey, false);
      
      // Resetar tentativas falhas e lockout para o PIN
      await prefs.setInt(_failAttemptsKey, 0);
      await prefs.remove(_lockoutTimeKey);

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
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(pin);

    // Usando PBKDF2 com SHA256 e 100.000 iterações para segurança
    final Hmac hmac = Hmac(sha256, saltBytes);
    final Digest digest = hmac.convert(pinBytes);

    // Para simular iterações do PBKDF2 de forma simples (não é PBKDF2 real, mas melhora o hash atual)
    // Em um ambiente real, usaria uma implementação de PBKDF2 de uma biblioteca como 'pointycastle'
    // ou 'flutter_sodium' para Argon2/scrypt.
    var input = digest.bytes;
    for (int i = 0; i < 100000; i++) {
      input = sha256.convert(input).bytes;
    }

    return base64.encode(input);
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
    
    // Lockout após 5 tentativas
    if (newAttempts >= 5) {
      final lockoutDuration = _getLockoutDuration(newAttempts);
      final lockoutTime = DateTime.now().millisecondsSinceEpoch + lockoutDuration;
      await prefs.setInt(_lockoutTimeKey, lockoutTime);
    }
  }

  static int _getLockoutDuration(int attempts) {
    // Lockout progressivo mais suave: 30s, 1min, 3min, 5min
    const durations = [30000, 60000, 180000, 300000]; // em milissegundos
    final index = (attempts - 5).clamp(0, durations.length - 1);
    return durations[index];
  }

  // Obter tentativas falhadas
  static Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_failAttemptsKey) ?? 0;
  }
}