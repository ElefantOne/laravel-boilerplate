<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use DateTimeInterface;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

final class UserTest extends TestCase
{
    public function test_user_casts_and_hides_sensitive_attributes(): void
    {
        $user = new User([
            'name' => 'Example User',
            'email' => 'user@example.com',
            'password' => 'example-password',
        ]);
        $user->email_verified_at = '2025-01-02 03:04:05';
        $user->setRememberToken('example-token');

        $this->assertTrue(Hash::check('example-password', $user->getAuthPassword()));
        $this->assertInstanceOf(DateTimeInterface::class, $user->email_verified_at);
        $this->assertSame('2025-01-02 03:04:05', $user->email_verified_at->format('Y-m-d H:i:s'));

        $serialized = $user->toArray();
        $this->assertSame('user@example.com', $serialized['email']);
        $this->assertArrayNotHasKey('password', $serialized);
        $this->assertArrayNotHasKey('remember_token', $serialized);
    }
}
