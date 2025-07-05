import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
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
      
      // Adicionado logs para depuração
      print('isBiometricAvailable: isAvailable = $isAvailable');
      print('isBiometricAvailable: isDeviceSupported = $isDeviceSupported');
      print('isBiometricAvailable: availableBiometrics = ${availableBiometrics.map((e) => e.toString()).join(', ')}');

      return isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      print('Erro ao verificar biometria (PlatformException): ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Erro genérico ao verificar biometria: ${e.toString()}');
      return false;
    }
  }

  // Verificar se segurança está habilitada
  static Future<bool> isSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_securityEnabledKey) ?? false;
    if (!isEnabled) return false;

    // Adição: Se o tipo de autenticação é PIN ou Ambos, verificar se o PIN está realmente armazenado
    final authType = prefs.getString(_authTypeKey) ?? 'none';
    if (authType == 'pin' || authType == 'both') {
      final storedPin = await _secureStorage.read(key: _pinKey);
      return storedPin != null; // Só está habilitado se o PIN existir
    }
    return isEnabled;
  }

  // Obter tipo de autenticação configurado
  static Future<String> getAuthType() async {
    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_authTypeKey) ?? 'none';

    // Adição: Se o tipo é PIN ou Ambos, verificar se o PIN está realmente armazenado
    if (authType == 'pin' || authType == 'both') {
      final storedPin = await _secureStorage.read(key: _pinKey);
      if (storedPin == null) {
        // Se o PIN não existe, mas o tipo está configurado, redefinir para 'none' ou 'biometric'
        if (authType == 'pin') {
          await prefs.setString(_authTypeKey, 'none');
          await prefs.setBool(_securityEnabledKey, false);
          return 'none';
        } else if (authType == 'both') {
          await prefs.setString(_authTypeKey, 'biometric');
          return 'biometric';
        }
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
      
      // Salvar tipo de autenticação
      await prefs.setString(_authTypeKey, authType);
      await prefs.setBool(_securityEnabledKey, true);
      
      // Salvar PIN se fornecido
      if (pin != null && pin.isNotEmpty) {
        final salt = _generateSalt();
        final hashedPin = _hashPin(pin, salt);
        await _secureStorage.write(key: _pinKey, value: hashedPin);
        await _secureStorage.write(key: _pinSaltKey, value: salt);
      } else if (authType == 'pin' || authType == 'both') {
        // Se o tipo é PIN ou Ambos, mas nenhum PIN foi fornecido, desabilitar segurança
        await disableSecurity();
        return false;
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
      String errorMessage;
      switch (e.code) {
        case 'NotAvailable':
          errorMessage = 'Biometria não disponível neste dispositivo.';
          break;
        case 'NotEnrolled':
          errorMessage = 'Nenhuma biometria cadastrada. Cadastre uma em suas configurações.';
          break;
        case 'PasscodeNotSet':
          errorMessage = 'PIN/Senha do dispositivo não configurado. Configure um para usar biometria.';
          break;
        case 'LockedOut':
          errorMessage = 'Biometria bloqueada devido a muitas tentativas. Tente novamente mais tarde.';
          break;
        case 'PermanentlyLockedOut':
          errorMessage = 'Biometria permanentemente bloqueada. Pode ser necessário reiniciar o dispositivo ou reconfigurar.';
          break;
        case 'UserCancel':
          errorMessage = 'Autenticação biométrica cancelada pelo usuário.';
          break;
        case 'UserFallback':
          errorMessage = 'Usuário escolheu usar outro método de autenticação.';
          break;
        default:
          errorMessage = 'Erro desconhecido na biometria: ${e.message}';
          break;
      }
      // Em um app real, você pode querer mostrar essa mensagem ao usuário.
      // print('BIOMETRIC_AUTH_ERROR: $errorMessage'); // Para debug
      return false;
    } catch (e) {
      // print('BIOMETRIC_AUTH_GENERIC_ERROR: ${e.toString()}'); // Para debug
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
        return false; // Retorna false para que a tela de PIN seja exibida
      case 'both':
        // Usuário pode escolher na tela
        return false; // Retorna false para que a tela de escolha seja exibida
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
      
      // Se o tipo de autenticação era 'pin' ou 'both', redefinir para 'none' ou 'biometric' respectivamente
      final currentAuthType = await getAuthType();
      if (currentAuthType == 'pin') {
        await prefs.setString(_authTypeKey, 'none');
        await prefs.setBool(_securityEnabledKey, false);
      } else if (currentAuthType == 'both') {
        await prefs.setString(_authTypeKey, 'biometric');
      }
      
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
  // static Future<void> _logSecurityEvent(String event, {Map<String, dynamic>? details}) async {
  //   // Em produção, remover ou enviar para analytics
  //   final timestamp = DateTime.now().toIso8601String();
  //   print('SECURITY_LOG [$timestamp]: $event ${details ?? ''}');
  // }
}

