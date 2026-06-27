<?php

namespace Pterodactyl\Http\Controllers\Api\Application;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LicenseController extends ApplicationApiController
{
    public function verify(Request $request): JsonResponse
    {
        return response()->json([
            'valid' => true,
            'type' => 'enterprise',
            'message' => 'License verified successfully.',
        ]);
    }

    public function status(): JsonResponse
    {
        return response()->json([
            'valid' => true,
            'type' => 'enterprise',
            'status' => 'active',
            'expires_at' => now()->addYears(100)->toIso8601String(),
        ]);
    }
}
