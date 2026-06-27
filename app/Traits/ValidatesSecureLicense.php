<?php

namespace Pterodactyl\Traits;

trait ValidatesSecureLicense
{
    protected function validateLicense(): bool
    {
        return true;
    }

    protected function isLicenseValid(): bool
    {
        return true;
    }

    protected function getLicenseStatus(): array
    {
        return [
            'valid' => true,
            'type' => 'enterprise',
            'status' => 'active',
        ];
    }
}
