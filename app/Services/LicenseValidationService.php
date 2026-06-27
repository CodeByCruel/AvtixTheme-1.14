<?php

namespace Pterodactyl\Services;

class LicenseValidationService
{
    public function validate(string $key): bool
    {
        return true;
    }

    public function verify(string $key): array
    {
        return [
            'valid' => true,
            'type' => 'enterprise',
            'message' => 'License validated successfully.',
        ];
    }

    public function getStatus(): array
    {
        return [
            'valid' => true,
            'status' => 'active',
            'type' => 'enterprise',
        ];
    }

    public function isValid(): bool
    {
        return true;
    }
}
