import { Controller, Post, Body, Get, Param } from '@nestjs/common';
import { EapActionsService } from './eap-actions.service';
import { User } from '../user/user.decorator';
import { ApiImplicitParam, ApiOperation } from '@nestjs/swagger';
import { EapActionDto } from './dto/eap-action.dto';
import { EapActionEntity } from './eap-action.entity';
import { EapActionStatusEntity } from './eap-action-status.entity';

@Controller('eap-actions')
export class EapActionsController {
  private readonly eapActionsService: EapActionsService;

  public constructor(eapActionsService: EapActionsService) {
    this.eapActionsService = eapActionsService;
  }

  @ApiOperation({ title: 'Check EAP actions as done' })
  @Post()
  public async checkAction(
    @User('id') userId: number,
    @Body() eapAction: EapActionDto,
  ): Promise<EapActionStatusEntity> {
    return await this.eapActionsService.checkAction(userId, eapAction);
  }

  @ApiOperation({ title: 'Check EAP actions as done' })
  @ApiImplicitParam({ name: 'countryCode', required: true, type: 'string' })
  @ApiImplicitParam({ name: 'area', required: true, type: 'string' })
  @Get('/:countryCode/:area')
  public async getActionsWithStatus(
    @Param() params,
  ): Promise<EapActionEntity[]> {
    return await this.eapActionsService.getActionsWithStatus(
      params.countryCode,
      params.area,
    );
  }
}