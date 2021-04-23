import {
  Column,
  Entity,
  JoinTable,
  ManyToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { BoundingBox } from '../data/geo.model';
import { LeadTimeEntity } from '../lead-time/lead-time.entity';
import { UserEntity } from '../user/user.entity';
import { AdminLevel } from './admin-level.enum';
import { CountryStatus } from './country-status.enum';
import { HazardModel } from './hazard-model.enum';

@Entity('country')
export class CountryEntity {
  @PrimaryGeneratedColumn('uuid')
  public countryId: string;

  @Column({ unique: true })
  public countryCodeISO3: string;

  @Column({ unique: true })
  public countryCodeISO2: string;

  @Column({ unique: true })
  public countryName: string;

  @Column()
  public hazardModel: HazardModel;

  @Column({ default: CountryStatus.Active })
  public countryStatus: CountryStatus;

  @Column({ default: AdminLevel.adm1 })
  public defaultAdminLevel: AdminLevel;

  @Column('text', {
    array: true,
    default: (): string => 'array[]::text[]',
  })
  public adminRegionLabels: string[];

  @Column({ nullable: true })
  public eapLink: string;

  @Column('json', { nullable: true })
  public eapAlertClasses: JSON;

  @Column('text', {
    array: true,
    default: (): string => 'array[]::text[]',
  })
  public countryLogos: string[];

  @Column('geometry')
  public countryBoundingBox: BoundingBox;

  @Column({ type: 'timestamp', default: (): string => 'CURRENT_TIMESTAMP' })
  public created: Date;

  @Column('json', { nullable: true })
  public glofasStationInput: JSON;

  @ManyToMany(
    (): typeof LeadTimeEntity => LeadTimeEntity,
    (leadTime): CountryEntity[] => leadTime.countries,
  )
  @JoinTable()
  public countryLeadTimes: LeadTimeEntity[];

  @ManyToMany(
    (): typeof UserEntity => UserEntity,
    (user): CountryEntity[] => user.countries,
  )
  public users: UserEntity[];
}
