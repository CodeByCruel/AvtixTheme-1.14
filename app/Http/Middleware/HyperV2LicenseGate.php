<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class HyperV2LicenseGate
{
    public function handle(Request $request, Closure $next)
    {
        return $next($request);
    }
}
