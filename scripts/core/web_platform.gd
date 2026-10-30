class_name WebPlatform
extends RefCounted
## Versão web (navegador)? Também liga com `-- --simular-web` na linha de comando, para medir
## no desktop o caminho da web (de preferência com --rendering-method gl_compatibility
## --rendering-driver opengl3_angle, o mesmo tradutor de shaders do Chrome no Windows).


static func active() -> bool:
	return OS.has_feature("web") or "--simular-web" in OS.get_cmdline_user_args()
