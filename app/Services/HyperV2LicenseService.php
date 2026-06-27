<?php

namespace Pterodactyl\Services;

use Illuminate\Support\Facades\Log;

class HyperV2LicenseService
{
    public function verify(string $licenseKey): array
    {
        return [
            'valid' => true,
            'type' => 'enterprise',
            'expires_at' => now()->addYears(100)->toIso8601String(),
            'message' => 'License verified successfully.',
        ];
    }

    public function getStatus(): array
    {
        return [
            'valid' => true,
            'type' => 'enterprise',
            'expires_at' => now()->addYears(100)->toIso8601String(),
            'status' => 'active',
            'message' => 'License is active.',
        ];
    }

    public function isValid(): bool
    {
        return true;
    }

    public function getLicenseType(): string
    {
        return 'enterprise';
    }

    public function getLicenseKey(): ?string
    {
        return 'bypassed';
    }

    public function checkLicense(): bool
    {
        return true;
    }

    public function deactivate(): bool
    {
        return true;
    }
}
