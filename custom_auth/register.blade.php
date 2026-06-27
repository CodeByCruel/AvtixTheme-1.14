<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Register - Avtix Game Panel</title>
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
        .register-container {
            width: 100%;
            max-width: 420px;
            padding: 2rem;
        }
        .register-box {
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
        .form-row {
            display: flex;
            gap: 0.75rem;
        }
        .form-row .form-group {
            flex: 1;
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
    </style>
</head>
<body>
    <div class="register-container">
        <div class="register-box">
            <div class="logo">
                <h1>Avtix Game Panel</h1>
                <p class="subtitle">Create a new account</p>
            </div>

            @if ($errors->any())
                <div class="error-box">
                    <ul style="list-style:none;padding:0;margin:0;">
                        @foreach ($errors->all() as $error)
                            <li>{{ $error }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif

            <form method="POST" action="{{ route('auth.custom.register') }}">
                @csrf

                <div class="form-row">
                    <div class="form-group">
                        <label for="name_first">First Name</label>
                        <input type="text" id="name_first" name="name_first" value="{{ old('name_first') }}" placeholder="First name">
                    </div>
                    <div class="form-group">
                        <label for="name_last">Last Name</label>
                        <input type="text" id="name_last" name="name_last" value="{{ old('name_last') }}" placeholder="Last name">
                    </div>
                </div>

                <div class="form-group">
                    <label for="username">Username</label>
                    <input type="text" id="username" name="username" value="{{ old('username') }}" placeholder="Choose a username" required autofocus>
                </div>

                <div class="form-group">
                    <label for="email">Email</label>
                    <input type="email" id="email" name="email" value="{{ old('email') }}" placeholder="you@example.com" required>
                </div>

                <div class="form-group">
                    <label for="password">Password</label>
                    <input type="password" id="password" name="password" placeholder="At least 8 characters" required>
                </div>

                <div class="form-group">
                    <label for="password_confirmation">Confirm Password</label>
                    <input type="password" id="password_confirmation" name="password_confirmation" placeholder="Repeat your password" required>
                </div>

                <button type="submit" class="btn">Create Account</button>
            </form>

            <div class="links">
                <p>Already have an account? <a href="{{ route('auth.custom.login') }}">Sign in</a></p>
            </div>
        </div>
    </div>
</body>
</html>
