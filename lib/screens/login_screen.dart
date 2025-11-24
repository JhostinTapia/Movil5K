import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _passwordController = TextEditingController();
  String _categoriaSeleccionada = 'estudiantes';
  bool _obscurePassword = true;

  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nombreController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Intentar login
      final loginExitoso = await authProvider.login(
        _nombreController.text.trim(),
        _passwordController.text,
      );

      // Si el login falló, mostrar error y NO navegar
      if (!loginExitoso) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      authProvider.error ?? 'Error al iniciar sesión',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return; // NO navegar si falló el login
      }

      // Login exitoso - Verificar que tenemos datos antes de navegar
      if (authProvider.juez == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error: No se pudo cargar la información del usuario',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return; // NO navegar si no hay datos del juez
      }

      // Conectar WebSocket después del login exitoso
      if (mounted) {
        try {
          await authProvider.connectWebSocket();
          debugPrint('✅ WebSocket conectado después del login');
        } catch (e) {
          debugPrint('⚠️ Error conectando WebSocket: $e');
          // No es crítico, continuar de todas formas
        }
      }

      // Todo bien - navegar a la pantalla de equipos
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/equipos');
      }
    }
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(flex: 1, child: Container()),
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNombreField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: _nombreController,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
          hintText: 'Email',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Por favor ingresa tu email';
          }
          if (!value.contains('@')) {
            return 'Email inválido';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey.shade400,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          hintText: 'Contraseña',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor ingresa tu contraseña';
          }
          if (value.length < 6) {
            return 'La contraseña debe tener al menos 6 caracteres';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCategoriaField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _categoriaSeleccionada,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
          style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
          items: const [
            DropdownMenuItem(
              value: 'estudiantes',
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.graduationCap,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(width: 12),
                  Text('Estudiantes por Equipos'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'interfacultades',
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.building,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(width: 12),
                  Text('Interfacultades por Equipos'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _categoriaSeleccionada = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: isLoading ? null : _handleLogin,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: isLoading ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.95 + (_animation.value * 0.05),
              child: child,
            );
          },
          child: Stack(
            children: [
              // Fondo con elementos decorativos
              _buildBackground(),

              // Contenido principal
              SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    children: [
                      const SizedBox(height: 80),

                      // Logo y título
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              Hero(
                                tag: 'logo',
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    FontAwesomeIcons.stopwatch,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Carrera 5K UNL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Sistema de Registro de Tiempos',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Formulario de login
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 25),
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Título del formulario
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: AppTheme.primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Inicio de Sesión - Juez',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 25),

                                  // Campo email
                                  _buildNombreField(),
                                  const SizedBox(height: 20),

                                  // Campo contraseña
                                  _buildPasswordField(),
                                  const SizedBox(height: 20),

                                  // Campo categoría
                                  _buildCategoriaField(),
                                  const SizedBox(height: 25),

                                  // Botón de login
                                  _buildLoginButton(authProvider.isLoading),
                                  const SizedBox(height: 20),

                                  // Información adicional
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.grey.shade500,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Sistema autónomo con sincronización automática',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
