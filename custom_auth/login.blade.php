<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Login - Avtix Game Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0c0a09;
            color: #d4d4d8;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            width: 100%;
            max-width: 420px;
            padding: 2rem;
        }
        .login-box {
            background: #1c1917;
            border: 1px solid rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 2.5rem;
        }
        .logo {
            text-align: center;
            margin-bottom: 2rem;
        }
        .logo h1 {
            font-size: 1.5rem;
            font-weight: 700;
            color: #fff;
            letter-spacing: -0.025em;
        }
        .logo .subtitle {
            color: #71717a;
            font-size: 0.875rem;
            margin-top: 0.25rem;
        }
        .form-group {
            margin-bottom: 1rem;
        }
        .form-group label {
            display: block;
            font-size: 0.875rem;
            font-weight: 500;
            color: #a1a1aa;
            margin-bottom: 0.375rem;
        }
        .form-group input {
            width: 100%;
            padding: 0.625rem 0.875rem;
            background: #27272a;
            border: 1px solid #3f3f46;
            border-radius: 8px;
            color: #fff;
            font-size: 0.875rem;
            outline: none;
            transition: border-color 0.15s;
        }
        .form-group input:focus {
            border-color: #df3050;
        }
        .form-group input::placeholder {
            color: #52525b;
        }
        .error-text {
            color: #ef4444;
            font-size: 0.75rem;
            margin-top: 0.25rem;
        }
        .error-box {
            background: rgba(239,68,68,0.1);
            border: 1px solid rgba(239,68,68,0.3);
            border-radius: 8px;
            padding: 0.75rem 1rem;
            margin-bottom: 1rem;
            color: #fca5a5;
            font-size: 0.8125rem;
        }
        .btn {
            width: 100%;
            padding: 0.75rem;
            background: #df3050;
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 0.875rem;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.15s;
            margin-top: 0.5rem;
        }
        .btn:hover { background: #c12640; }
        .btn:disabled { opacity: 0.6; cursor: not-allowed; }
        .links {
            text-align: center;
            margin-top: 1.25rem;
            font-size: 0.8125rem;
            color: #71717a;
        }
        .links a {
            color: #df3050;
            text-decoration: none;
            font-weight: 500;
        }
        .links a:hover { text-decoration: underline; }
        .remember-row {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-bottom: 0.5rem;
        }
        .remember-row input[type="checkbox"] {
            accent-color: #df3050;
        }
        .remember-row label {
            font-size: 0.8125rem;
            color: #a1a1aa;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-box">
            <div class="logo">
                <h1>Avtix Game Panel</h1>
                <p class="subtitle">Sign in to your account</p>
            </div>

            @if ($errors->any())
                <div class="error-box">
                    {{ $errors->first('user') }}
                </div>
            @endif

            <form method="POST" action="{{ route('auth.custom.login') }}">
                @csrf

                <div class="form-group">
                    <label for="user">Username or Email</label>
                    <input type="text" id="user" name="user" value="{{ old('user') }}" placeholder="Enter your username or email" required autofocus>
                </div>

                <div class="form-group">
                    <label for="password">Password</label>
                    <input type="password" id="password" name="password" placeholder="Enter your password" required>
                </div>

                <div class="remember-row">
                    <input type="checkbox" id="remember" name="remember" value="1">
                    <label for="remember">Remember me</label>
                </div>

                <button type="submit" class="btn">Sign In</button>
            </form>

            <div class="links">
                <p>Don't have an account? <a href="{{ route('auth.custom.register') }}">Create one</a></p>
                <p style="margin-top:0.5rem"><a href="{{ route('auth.forgot-password') }}">Forgot password?</a></p>
            </div>
        </div>
    </div>
</body>
</html>
