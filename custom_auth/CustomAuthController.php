<?php

namespace Pterodactyl\Http\Controllers\Auth;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Http\RedirectResponse;
use Illuminate\Contracts\View\View;
use Pterodactyl\Models\User;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Pterodactyl\Facades\Activity;

class CustomAuthController extends AbstractLoginController
{
    public function showLogin()
    {
        if (Auth::check()) {
            return redirect('/dashboard');
        }
        return view('auth.login');
    }

    public function doLogin(Request $request): RedirectResponse
    {
        $request->validate([
            'user' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        if ($this->hasTooManyLoginAttempts($request)) {
            $this->fireLockoutEvent($request);
            return back()->withErrors(['user' => 'Too many login attempts. Please try again later.']);
        }

        $username = $request->input('user');
        $password = $request->input('password');

        try {
            $field = $this->getField($username);
            $user = User::query()->where($field, $username)->firstOrFail();
        } catch (ModelNotFoundException) {
            $this->incrementLoginAttempts($request);
            return back()->withErrors(['user' => 'Invalid credentials.'])->withInput(['user' => $username]);
        }

        if ($user->is_banned) {
            return back()->withErrors(['user' => 'Your account has been banned.']);
        }

        if ($user->suspended_until && \Carbon\Carbon::now()->lt($user->suspended_until)) {
            return back()->withErrors(['user' => 'Your account is suspended.']);
        }

        if (!password_verify($password, $user->password)) {
            $this->incrementLoginAttempts($request);
            return back()->withErrors(['user' => 'Invalid credentials.'])->withInput(['user' => $username]);
        }

        if ($user->use_totp) {
            $request->session()->put('auth_confirmation_token', [
                'user_id' => $user->id,
                'token_value' => $token = Str::random(64),
                'expires_at' => \Carbon\CarbonImmutable::now()->addMinutes(5),
            ]);
            return redirect('/auth/login/checkpoint')->with('token', $token);
        }

        $this->clearLoginAttempts($request);
        Auth::login($user, $request->boolean('remember'));

        Activity::event('auth:login')->withRequestMetadata()->subject($user)->log();

        $intended = $request->session()->pull('url.intended', '/dashboard');
        return redirect($intended);
    }

    public function showRegister()
    {
        if (Auth::check()) {
            return redirect('/dashboard');
        }
        return view('auth.register');
    }

    public function doRegister(Request $request): RedirectResponse
    {
        $request->validate([
            'username' => ['required', 'string', 'max:191', 'unique:users,username'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'name_first' => ['nullable', 'string', 'max:255'],
            'name_last' => ['nullable', 'string', 'max:255'],
        ]);

        $userId = DB::table('users')->insertGetId([
            'uuid' => (string) Str::uuid(),
            'username' => $request->input('username'),
            'email' => $request->input('email'),
            'password' => Hash::make($request->input('password')),
            'name_first' => $request->input('name_first', ''),
            'name_last' => $request->input('name_last', ''),
            'language' => 'en',
            'root_admin' => false,
            'use_totp' => false,
            'gravatar' => true,
            'credit' => '0.00',
            'referral_balance' => '0.00',
            'external_id' => '',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $user = User::find($userId);
        Auth::login($user);

        Activity::event('auth:register')->withRequestMetadata()->subject($user)->log();

        return redirect('/dashboard');
    }

    public function doLogout(Request $request): RedirectResponse
    {
        $user = $request->user();
        if ($user) {
            Activity::event('auth:logout')->withRequestMetadata()->subject($user)->log();
            Auth::guard()->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }
        return redirect('/auth/login');
    }

    protected function getField(?string $input = null): string
    {
        return filter_var($input, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
    }
}
